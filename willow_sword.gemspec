$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "willow_sword/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "willow_sword"
  s.version     = WillowSword::VERSION
  s.authors     = ["Martyn Whitwell", "Anusha Ranganathan"]
  s.email       = ["martyn@cottagelabs.com", "anusha@cottagelabs.com"]
  s.homepage    = "https://github.com/cottagelabs/willow_sword"
  s.summary     = "WillowSword is a plugin which provides SWORDv2 server functionality in the Willow application"
  s.description = "WillowSword is work in progress"
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  s.add_dependency "rails", ">= 6.1"
  s.add_dependency "bagit", ">= 0.4"
  s.add_dependency "rubyzip", ">= 1.0.0"
  s.add_development_dependency 'rspec-rails'
  s.add_development_dependency 'shoulda-matchers'
  s.add_development_dependency 'factory_girl_rails'
  s.test_files = Dir["spec/**/*"]

end
