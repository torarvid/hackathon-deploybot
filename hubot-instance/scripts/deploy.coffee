# Description:
#   Deploy scripts.

exec = require('child_process').exec
fs = require('fs')
yaml = require('js-yaml')

config =
  secrets_dir: process.env.HUBOT_SECRETS_DIR
  logs_dir: process.env.HUBOT_LOGS_DIR
  config_dir: process.env.HUBOT_CONFIG_DIR
  docker_env_file: process.env.HUBOT_DOCKER_ENV_FILE
  docker_image: process.env.HUBOT_DOCKER_IMAGE

module.exports = (robot) ->

  class DeployConfig
    constructor: (env, component) ->
      @deploying = false
      @env = env
      @component = component

  class Deployer
    constructor: ->
      @deploying = false
      @docker_volumes = "-v #{config.secrets_dir}:/secrets" +
        " -v #{config.logs_dir}:/logs" +
        " -v #{config.config_dir}:/config"
      @docker_cmd = "./deploy.sh"
      @config_valid = config.secrets_dir and config.logs_dir and config.docker_env_file and
        config.docker_image and config.config_dir

      @envConfigs = {}
      envConfig = yaml.load(fs.readFileSync(config.config_dir + "/config.yml"))
      robot.logger.info("Read YAML #{JSON.stringify(envConfig)}")

      for envName, env of envConfig.environments
        for component in env.components
          desc = "deploy the :wowbox: component #{component.name} to #{envName}"
          robot.commands.push("hubot deploy #{envName} #{component.name} - #{desc}")
          @envConfigs["#{envName}:#{component.name}"] = new DeployConfig(envName, component)

    _getDockerOptions: (targetEnv) ->
      envFile = config.docker_env_file.replace("%TARGET_ENV%", targetEnv)
      return "#{@docker_volumes} --env-file #{envFile}"

    deploy: (argString, res) ->
      unless @config_valid
        res.send "Dude. Some admin l0ser didn't config me right. Can't do nothing!"
        return
      args = argString.split(' ')
      unless args.length > 1
        res.send "Yo, this don't make sense, yo. What am I gonna do with '#{argString}'? " +
          "Try 'help deploy'."
        return
      env = args[0]
      component = args[1]
      key = "#{env}:#{component}"
      unless key of @envConfigs
        res.send "Yo, this don't make sense, yo. What am I gonna do with '#{argString}'? " +
          "Try 'help deploy'."
        return

      deployCfg = @envConfigs[key]
      if deployCfg.deploying
        res.send 'Deploying already, yo. Stop bugging me'
        return
      deployCfg.deploying = true
      res.send "Deploying '#{component}' to '#{env}', yo"
      opts = @_getDockerOptions(env)
      img = config.docker_image
      cmdLine = "echo docker run #{opts} #{img} #{@docker_cmd} #{env} #{component}"
      child = exec(cmdLine, @deployDone.bind(this, deployCfg, res))

    deployDone: (deployCfg, res, error, stdout, stderr) ->
      deployCfg.deploying = false
      console.log "Deploy done. Whoa?!?!?! Error:#{error}, STDOUT: #{stdout}, STDERR: #{stderr}"
      if error
        res.send "@here_schmiere: Aye caramba, there was an error deploying " +
          "'#{deployCfg.component}' on '#{deployCfg.env}'. Are we down? Error was: #{error}"
      else
        res.send "@here_schmiere: There's a shiny new version of '#{deployCfg.component.name}' " +
          "on '#{deployCfg.env}' (Should be at least, I don't really know :face_with_rolling_eyes:)"

  robot.deployer = new Deployer

  robot.respond /deploy ?(.*)?$/i, (res) ->
    # unless robot.auth.hasRole(res.envelope.user, 'deployers')
    #   res.send "Nah, you're not a deployer. Talk to the :hand:"
    #   return
    robot.logger.debug(res)
    args = res.match[1]
    unless args and args.length > 0
      res.send "Whatcha wanna deploy, yo? Try 'help deploy'."
      return
    robot.deployer.deploy(args, res)
