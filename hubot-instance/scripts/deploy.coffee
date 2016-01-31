# Description:
#   Deploy scripts.

exec = require('child_process').exec

config =
  secrets_dir: process.env.HUBOT_SECRETS_DIR
  logs_dir: process.env.HUBOT_LOGS_DIR
  config_dir: process.env.HUBOT_CONFIG_DIR
  docker_env_file: process.env.HUBOT_DOCKER_ENV_FILE
  docker_image: process.env.HUBOT_DOCKER_IMAGE

fs = require('fs')

module.exports = (robot) ->

  robot.commands.push("hubot deploy staging|prod - deploy the :wowbox: to staging or prod")

  class Deployer
    constructor: ->
      @deploying = false
      @docker_volumes = "-v #{config.secrets_dir}:/secrets -v #{config.logs_dir}:/logs"
      @docker_env = "--env-file #{config.docker_env_file}"
      @docker_options = "#{@docker_volumes} #{@docker_env}"
      @docker_cmd = "./deploy.sh"
      @config_valid = config.secrets_dir and config.logs_dir and config.docker_env_file and
        config.docker_image and config.config_dir

    isDeploying: ->
      return @deploying

    deploy: (target, res) ->
      unless @config_valid
        res.send "Dude. Some admin l0ser didn't config me right. Can't do nothing!"
        return
      if @isDeploying()
        res.send 'Deploying already, yo. Stop bugging me'
        return
      @deploying = true
      res.send "Deploying to #{target}, yo"
      cmdLine = "docker run #{@docker_options} #{config.docker_image} #{@docker_cmd} #{target}"
      child = exec(cmdLine, @deployDone.bind(this, target, res))

    deployDone: (target, res, error, stdout, stderr) ->
      @deploying = false
      console.log "Deploy done. Whoa?!?!?! Error:#{error}, STDOUT: #{stdout}, STDERR: #{stderr}"
      if error
        res.send "@here_schmiere: Aye caramba, there was a deployment error on '#{target}'. Are we down? Error was: #{error}"
      else
        res.send "@here_schmiere: There's a shiny new version on '#{target}' (Should be at least, I don't really know :face_with_rolling_eyes:)"

  robot.deployer = new Deployer

  robot.respond /deploy ?(.*)?$/i, (res) ->
    unless robot.auth.hasRole(res.envelope.user, 'deployers')
      res.send "Nah, you're not a deployer. Talk to the :hand:"
      return
    robot.logger.debug(res)
    target = res.match[1]
    if target is "prod" or target is "staging"
      robot.deployer.deploy(target, res)
    else if target and target.length > 0
      res.send "I can do 'deploy prod' or 'deploy staging', but you asked about '#{target}'"
    else
      res.send "I can do 'deploy prod' or 'deploy staging', but you needz to tell me"
