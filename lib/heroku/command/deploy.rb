require 'heroku/command/base'
require "heroku/client/heroku_postgresql"
require "heroku/helpers/heroku_postgresql"
require "heroku/client/heroku_postgresql_backups"
require "heroku/command/run"

class Heroku::Command::Deploy < Heroku::Command::BaseWithApp
  include Heroku::Helpers::HerokuPostgresql

  # deploy
  #
  #   -f, --force  # Run deploy with git push --force
  #   -m, --migration  # Run backup and migration if it exists
  #
  # Deploy app to heroku with database backup and migration
  def index
    validate_arguments!
    requires_preauth
    branch = git("rev-parse --abbrev-ref HEAD")
    remote = git("remote -v | grep #{app} | head -n 1 |  cut -d\\\t -f 1")


    #checking deploy needs
    last_local_commit = git("rev-parse HEAD")
    last_remote_commit = git("ls-remote --heads #{remote} | cut -d\\\t -f 1")
    if last_local_commit == last_remote_commit
      display("\e[32mEverything up-to-date. Nothing to deploy.\e[0m")
      exit
    end

    display
    display("\e[32mStarting deploy branch \e[33m#{branch}\e[32m to \e[33m#{app}\e[0m")
    display

    # checking dirty status for git
    dirty = git("status -s --ignore-submodules=dirty").strip
    error("Repository has un-committed changes. Commit or stash changes before deploy.") if dirty.length > 0

    require_migration = false
    require_pgbackups = false
    install_pgbackups = false
    full_deploy = false
    attachment = nil

    action("Pre-deploy checking") do
      #check migrations
      attachment = Resolver.new(app, api).resolve("DATABASE_URL")
      url = attachment.url
      uri = URI.parse(url)
      ENV["PGPASSWORD"] = uri.password
      ENV["PGSSLMODE"]  = "require"
      sql = %Q(-c "select * from schema_migrations order by version desc")
      cmd = "psql -t -U #{uri.user} -h #{uri.host} -p #{uri.port || 5432} #{sql} #{uri.path[1..-1]}"
      last_remote_migration_dates = %x{ #{cmd} 2>&1 }.split("\n").map(&:strip)
      last_local_migration_dates = %x{ ls -1 ./db/migrate/ | cut -d_ -f 1 2>&1 }.split("\n").map(&:strip)
      require_migration = (last_local_migration_dates - last_remote_migration_dates).length > 0
    end

    if require_migration
      if options[:migration]
        full_deploy = true
      else
        display
        display("\e[32mNew release has new database migrations.")
        full_deploy = confirm("Do you want to deploy with database backup and migration? (y/n)\e[0m")
        display
      end
    end

    if full_deploy
      msg = "Running database backup..."
      display(msg, false)
      backup = Heroku::Client::HerokuPostgresql.new(attachment).backups_capture
      uuid = backup[:uuid]
      num = backup[:num]
      ticks = 0
      begin
        backup = Heroku::Client::HerokuPostgresqlApp.new(app).transfers_get(uuid)
        status = if backup[:started_at]
                   format_bytes(backup[:processed_bytes])
                 else
                   spinner(ticks)
                 end
        redisplay "#{msg}#{status}"
        ticks += 1
        sleep 1
      end until backup[:finished_at]
      redisplay("#{msg}done (b#{format("%03d", num)})", true)
    end

    action("Enabling maintenance mode") do
      api.post_app_maintenance(app, '1')
    end if full_deploy

    cmd = "git push #{remote} #{branch}:master"
    cmd += " --force" if options[:force]
    display cmd
    ok = system(cmd)

    if full_deploy
      if ok
        display
        runner = Heroku::Command::Run.new
        runner.send(:run_attached, "rake db:migrate")
      end
      display
      action("Disabling maintenance mode") do
        api.post_app_maintenance(app, '0')
      end
    end

    msg = if ok
            "\e[32mDeploy successfully finished\e[0m"
          else
            "\e[33m!!! Deploy failed\e[0m"
          end
      
    display
    display(msg)
  end
end
