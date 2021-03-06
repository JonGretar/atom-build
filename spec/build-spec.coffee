Build = require '../lib/build'
{WorkspaceView} = require 'atom';
fs = require 'fs-plus'
path = require 'path'
_ = require 'underscore'
temp = require 'temp'

describe "Build", ->
  goodMakefile = __dirname + '/fixture/Makefile.good'
  badMakefile = __dirname + '/fixture/Makefile.bad'
  longMakefile = __dirname + '/fixture/Makefile.long'
  goodGruntfile = __dirname + '/fixture/Gruntfile.js'
  goodNodefile = __dirname + '/fixture/package.json.node'
  goodAtomfile = __dirname + '/fixture/package.json.atom'
  badPackageJsonfile = __dirname + '/fixture/package.json.noengine'
  goodAtomBuildfile = __dirname + '/fixture/.atom-build.json'
  shellAtomBuildfile = __dirname + '/fixture/.atom-build.shell.json'
  replaceAtomBuildFile = __dirname + '/fixture/.atom-build.replace.json'
  shFalseAtomBuildFile = __dirname + '/fixture/.atom-build.sh-false.json'
  shTrueAtomBuildFile = __dirname + '/fixture/.atom-build.sh-true.json'
  shDefaultAtomBuildFile = __dirname + '/fixture/.atom-build.sh-default.json'

  directory = null;

  temp.track();

  beforeEach ->
    atom.workspaceView = new WorkspaceView
    atom.workspace = atom.workspaceView.model
    directory = fs.realpathSync(temp.mkdirSync { prefix: 'atom-build-spec-' } ) + '/';
    atom.project.setPath(directory);

    atom.config.set('build.arguments', '')
    atom.config.set('build.environment', '')
    atom.config.set('build.keepVisible', false)

    # Set up grunt
    fs.copySync(path.join(__dirname, 'fixture', 'node_modules'), path.join(directory, 'node_modules'));
    binGrunt = path.join(directory, 'node_modules', '.bin', 'grunt')
    realGrunt = path.join(directory, 'node_modules', 'grunt-cli', 'bin', 'grunt')
    fs.unlinkSync(binGrunt);
    fs.chmodSync(realGrunt, 0o700);
    fs.symlinkSync(realGrunt, binGrunt);

    jasmine.unspy window, 'setTimeout'
    jasmine.unspy window, 'clearTimeout'

    waitsForPromise ->
      atom.packages.activatePackage('build')

  afterEach ->
    fs.removeSync(directory)

  describe "when package is activated", ->
    it "should not show build window if keepVisible is false", ->
      expect(atom.workspaceView.find('.build')).not.toExist()

  describe "when build is triggered with Makefile", ->
    it "should not show the build window if no buildfile exists", ->
      expect(atom.workspaceView.find('.build')).not.toExist()

      atom.workspaceView.trigger 'build:trigger'

      waitsForPromise ->
        atom.workspaceView.open()

      runs ->
        expect(atom.workspaceView.find('.build')).not.toExist()

    it "should show the build window if buildfile exists", ->
      expect(atom.workspaceView.find('.build')).not.toExist()

      fs.writeFileSync(directory + 'Makefile', fs.readFileSync(goodMakefile));
      atom.workspaceView.trigger 'build:trigger'

      waitsFor ->
        atom.workspaceView.find('.build .title').hasClass('success')

      runs ->
        expect(atom.workspaceView.find('.build')).toExist()
        expect(atom.workspaceView.find('.build .output').text()).toMatch /Surprising is the passing of time\nbut not so, as the time of passing/;

    it "should show build failed if build fails", ->
      expect(atom.workspaceView.find('.build')).not.toExist()

      fs.writeFileSync(directory + 'Makefile', fs.readFileSync(badMakefile));
      atom.workspaceView.trigger 'build:trigger'

      waitsFor ->
        atom.workspaceView.find('.build .title').hasClass('error')

      runs ->
        expect(atom.workspaceView.find('.build')).toExist()
        expect(atom.workspaceView.find('.build .output').text()).toMatch /Very bad\.\.\./

    it "should cancel build when stopping it, and remove when stopping again", ->
      expect(atom.workspaceView.find('.build')).not.toExist()

      fs.writeFileSync(directory + 'Makefile', fs.readFileSync(longMakefile));
      atom.workspaceView.trigger 'build:trigger'

      # Let build run for one second before we terminate it
      waits 1000

      runs ->
        expect(atom.workspaceView.find('.build')).toExist()
        expect(atom.workspaceView.find('.build .output').text()).toMatch /Building, this will take some time.../
        atom.workspaceView.trigger 'build:stop'

      waitsFor ->
        atom.workspaceView.find('.build .title').hasClass('error')

      runs ->
        atom.workspaceView.trigger 'build:stop'

      waitsFor ->
        atom.workspaceView.find('.build .title').text() == 'Aborted!'

  describe "when build is triggered with grunt file", ->
    it "should show the build window", ->
      expect(atom.workspaceView.find('.build')).not.toExist()

      fs.writeFileSync(directory + 'Gruntfile.js', fs.readFileSync(goodGruntfile));
      atom.workspaceView.trigger 'build:trigger'

      waitsFor ->
        atom.workspaceView.find('.build .title').hasClass('success')

      runs ->
        expect(atom.workspaceView.find('.build')).toExist()
        expect(atom.workspaceView.find('.build .output').text()).toMatch /Surprising is the passing of time. But not so, as the time of passing/;

  describe "when build is triggered with package.json file", ->
    it "should show the build window if it is node engine", ->
      expect(atom.workspaceView.find('.build')).not.toExist()

      fs.writeFileSync(directory + 'package.json', fs.readFileSync(goodNodefile));
      atom.workspaceView.trigger 'build:trigger'

      waitsFor ->
        atom.workspaceView.find('.build .title').hasClass('success')

      runs ->
        expect(atom.workspaceView.find('.build')).toExist()
        expect(atom.workspaceView.find('.build .output').text()).toMatch /^Executing with sh: npm/

    it "should show the build window if it is atom engine", ->
      return if (process.env.TRAVIS)
      expect(atom.workspaceView.find('.build')).not.toExist()

      fs.writeFileSync(directory + 'package.json', fs.readFileSync(goodAtomfile))
      atom.workspaceView.trigger 'build:trigger'

      waitsFor (-> atom.workspaceView.find('.build .title').hasClass('success')),
        "build to be successful", 10000

      runs ->
        expect(atom.workspaceView.find('.build')).toExist()
        expect(atom.workspaceView.find('.build .output').text()).toMatch /^Executing with sh: apm/

    it "should not do anything if engines are not available in the file", ->
      expect(atom.workspaceView.find('.build')).not.toExist()

      fs.writeFileSync(directory + 'package.json', fs.readFileSync(badPackageJsonfile))
      atom.workspaceView.trigger 'build:trigger'

      waits 1000

      runs ->
        expect(atom.workspaceView.find('.build')).not.toExist()


  describe "when custom .atom-build.json is available", ->
    it "should show the build window", ->
      expect(atom.workspaceView.find('.build')).not.toExist();

      fs.writeFileSync(directory + '.atom-build.json', fs.readFileSync(goodAtomBuildfile))
      atom.workspaceView.trigger 'build:trigger'

      waitsFor ->
        atom.workspaceView.find('.build .title').hasClass('success')

      runs ->
        expect(atom.workspaceView.find('.build')).toExist()
        expect(atom.workspaceView.find('.build .output').text()).toMatch /"cmd": "dd"/

    it "should be possible to exec shell commands with wildcard expansion", ->
      expect(atom.workspaceView.find('.build')).not.toExist();

      fs.writeFileSync(directory + '.atom-build.json', fs.readFileSync(shellAtomBuildfile))
      atom.workspaceView.trigger 'build:trigger'

      waitsFor ->
        atom.workspaceView.find('.build .title').hasClass('success')

      runs ->
        expect(atom.workspaceView.find('.build')).toExist()
        # The text to match can be anything since this is the file that 'dd' in .atom-build reads and outputs
        expect(atom.workspaceView.find('.build .output').text()).toMatch /Good news, everyone!/

    it "should show sh message if sh is true", ->
      expect(atom.workspaceView.find('.build')).not.toExist();

      fs.writeFileSync(directory + '.atom-build.json', fs.readFileSync(shTrueAtomBuildFile))
      atom.workspaceView.trigger 'build:trigger'

      waitsFor ->
        atom.workspaceView.find('.build .title').hasClass('success')

      runs ->
        expect(atom.workspaceView.find('.build')).toExist()
        expect(atom.workspaceView.find('.build .output').text()).toMatch /Executing with sh:/;

    it "should not show sh message if sh is false", ->
      expect(atom.workspaceView.find('.build')).not.toExist();

      fs.writeFileSync(directory + '.atom-build.json', fs.readFileSync(shFalseAtomBuildFile))
      atom.workspaceView.trigger 'build:trigger'

      waitsFor ->
        atom.workspaceView.find('.build .title').hasClass('success')

      runs ->
        expect(atom.workspaceView.find('.build')).toExist()
        expect(atom.workspaceView.find('.build .output').text()).toMatch /Executing:/;

    it "should show sh message if sh is unspecified", ->
      expect(atom.workspaceView.find('.build')).not.toExist();

      fs.writeFileSync(directory + '.atom-build.json', fs.readFileSync(shDefaultAtomBuildFile))
      atom.workspaceView.trigger 'build:trigger'

      waitsFor ->
        atom.workspaceView.find('.build .title').hasClass('success')

      runs ->
        expect(atom.workspaceView.find('.build')).toExist()
        expect(atom.workspaceView.find('.build .output').text()).toMatch /Executing with sh:/;


  describe "when multiple build options are available", ->
    it "should prioritise .atom-build.json over node", ->
      expect(atom.workspaceView.find('.build')).not.toExist()

      fs.writeFileSync(directory + '.atom-build.json', fs.readFileSync(goodAtomBuildfile))
      fs.writeFileSync(directory + 'package.json', fs.readFileSync(goodNodefile));
      atom.workspaceView.trigger 'build:trigger'

      waitsFor (-> atom.workspaceView.find('.build .title').hasClass('success'))

      runs ->
        expect(atom.workspaceView.find('.build')).toExist()
        expect(atom.workspaceView.find('.build .output').text()).toMatch /"cmd": "dd"/

    it "should prioritise grunt over make", ->
      expect(atom.workspaceView.find('.build')).not.toExist()

      fs.writeFileSync(directory + 'Gruntfile.js', fs.readFileSync(goodGruntfile));
      fs.writeFileSync(directory + 'Makefile', fs.readFileSync(goodMakefile));
      atom.workspaceView.trigger 'build:trigger'

      waitsFor ->
        atom.workspaceView.find('.build .title').hasClass('success')

      runs ->
        expect(atom.workspaceView.find('.build')).toExist()
        expect(atom.workspaceView.find('.build .output').text()).toMatch /Running "default" task/

    it "should prioritise node over grunt", ->
      expect(atom.workspaceView.find('.build')).not.toExist()

      fs.writeFileSync(directory + 'Gruntfile.js', fs.readFileSync(goodGruntfile));
      fs.writeFileSync(directory + 'package.json', fs.readFileSync(goodNodefile));
      atom.workspaceView.trigger 'build:trigger'

      waitsFor ->
        atom.workspaceView.find('.build .title').hasClass('success')

      runs ->
        expect(atom.workspaceView.find('.build')).toExist()
        expect(atom.workspaceView.find('.build .output').text()).toMatch /^Executing with sh: npm/

    it "should prioritise atom over grunt", ->
      return if (process.env.TRAVIS)
      expect(atom.workspaceView.find('.build')).not.toExist()

      fs.writeFileSync(directory + 'Gruntfile.js', fs.readFileSync(goodGruntfile));
      fs.writeFileSync(directory + 'package.json', fs.readFileSync(goodAtomfile));
      atom.workspaceView.trigger 'build:trigger'

      waitsFor (-> atom.workspaceView.find('.build .title').hasClass('success')),
        "build to be successful", 10000

      runs ->
        expect(atom.workspaceView.find('.build')).toExist()
        expect(atom.workspaceView.find('.build .output').text()).toMatch /^Executing with sh: apm/

  describe "when package.json exists, but without engines and Makefile is present", ->
    it "(Issue#3) should run Makefile without any npm arguments", ->
      expect(atom.workspaceView.find('.build')).not.toExist()

      fs.writeFileSync(directory + 'package.json', fs.readFileSync(badPackageJsonfile));
      fs.writeFileSync(directory + 'Makefile', fs.readFileSync(goodMakefile));

      atom.workspaceView.trigger 'build:trigger'

      waitsFor ->
        atom.workspaceView.find('.build .title').hasClass('success')

      runs ->
        expect(atom.workspaceView.find('.build')).toExist()
        expect(atom.workspaceView.find('.build .output').text()).toMatch /Surprising is the passing of time\nbut not so, as the time of passing/;

  describe "when build is started with deprecated valued", ->
    it "should show deprecation warning", ->
      expect(atom.workspaceView.find('.build')).not.toExist()

      atom.config.set('build.arguments', 'all')

      fs.writeFileSync(directory + 'Makefile', fs.readFileSync(goodMakefile));
      atom.workspaceView.trigger 'build:trigger'

      waitsFor ->
        atom.workspaceView.find('.build .title').hasClass('warning')

      runs ->
        expect(atom.workspaceView.find('.build')).toExist()
        expect(atom.workspaceView.find('.build .output').text()).toMatch /Surprising is the passing of time\nbut not so, as the time of passing/;

  describe "when replacements are specified in the atom-build.json file", ->
    it "should replace those with their dynamic value", ->

      expect(atom.workspaceView.find('.build')).not.toExist();

      fs.writeFileSync(directory + '.atom-build.json', fs.readFileSync(replaceAtomBuildFile))

      waitsForPromise ->
        atom.workspace.open '.atom-build.json'

      runs ->
        atom.workspaceView.trigger 'build:trigger'

      waitsFor ->
        atom.workspaceView.find('.build .title').hasClass('success')

      runs ->
        expect(atom.workspaceView.find('.build')).toExist()
        output = atom.workspaceView.find('.build .output').text()

        expect(output.indexOf('PROJECT_PATH=' + directory.substring(0, -1))).not.toBe -1
        expect(output.indexOf('FILE_ACTIVE=' + directory + '.atom-build.json')).not.toBe -1
        expect(output.indexOf('FROM_ENV=' + directory + '.atom-build.json')).not.toBe -1
