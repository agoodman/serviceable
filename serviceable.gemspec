Gem::Specification.new do |s|
  s.name         = 'serviceable'
  s.version      = '0.7.1'
  s.date         = '2017-10-22'
  s.summary      = "Standardized Rails web services with design-time configuration and query string filtering support"
  s.description  = "Decorate your controller classes with acts_as_service :model_name, and instantly support JSON/XML CRUD interface. Allow client to specify response contents using query string filter parameters."
  s.authors      = ["Aubrey Goodman"]
  s.email        = 'aubrey.goodman@gmail.com'
  s.files        = Dir["{lib}/**/*.rb", "LICENSE", "*.md"]
  s.require_path = 'lib'
  s.homepage     = 'https://github.com/agoodman/serviceable'
  s.license      = 'MIT'
end

