#!/usr/bin/env node

var fs = require('fs');
var yaml = require('js-yaml');

var config = yaml.load(fs.readFileSync('../../config/config.yml'));

if (process.argv.length < 4) {
  console.error('Usage: deploy.js <env> <component>');
  process.exit(1);
}
var envName = process.argv[2];
var componentName = process.argv[3];

var env = config.environments[envName];

var getComponent = () => {
  for (var c of env.components) {
    if (c.name === componentName) {
      return c;
    }
  }
  return null;
}
var component = getComponent();

if (!component) {
  console.error('No component found');
  process.exit(2);
}

function spawn(command, args, options) {
  return new Promise((resolve, reject) => {
    var spawn = require('child_process').spawn;
    var cmd = spawn(command, args, options);

    cmd.stdout.on('data', function(data) {
      console.log(data.toString('utf8'));
    });

    cmd.stderr.on('data', function(data) {
      console.log(data.toString('utf8'));
    });

    cmd.on('exit', function(code) {
      resolve(code);
    });
  });
}

process.chdir('../../wowbox/' + component.base_dir);
if (component.type === 'nova') {
  console.log('CWD', process.cwd());
  var blah = `nova --profile ${envName} ${component.nova_params} --verbose build ${component.nova_build}`;
  console.log('spawning', blah);
  spawn('echo', [blah])
    .then(code => console.log('exited with', code))
    .catch(e => console.log('noes', e));
}
