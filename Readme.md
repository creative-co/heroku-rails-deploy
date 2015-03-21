## heroku-rails-deploy

A heroku plugin for enterprise deployment rails applications

### Installation

```bash
$ heroku plugins:install git://github.com/cloudcastle/heroku-rails-deploy.git
```

#### Update

```bash
$ heroku plugins:update git://github.com/cloudcastle/heroku-rails-deploy.git
```


### Usage

Enterprise Deployment includes:
1) Checking new database migrations
2) * Running database backup (if new migrations exist)
3) * Enabling maintenance (if new migrations exist)
4) Git push
5) * Running migrations (if exist)
6) * Disabling maintenance (if new migrations exist)

* steps are optional


```bash
$ heroku deploy --app HEROKU_APP
  ...
  deploy current branch to HEROKU_APP
```

```bash
$ heroku deploy -f --app HEROKU_APP
  ...
  deploy current branch to HEROKU_APP using git push --force
```

```bash
$ heroku deploy -m --app HEROKU_APP
  ...
  auto-confirm running migration (full deploy)
```
