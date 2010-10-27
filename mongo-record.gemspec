Gem::Specification.new do |s|
  s.name = 'mongo_record-fotopedia'
  s.version = '0.5.2'
  s.platform = Gem::Platform::RUBY
  s.summary = 'ActiveRecord-like models for MongoDB'
  s.description = 'Note: this gem is no longer offically supported by 10gen. For a list of MongoDB object mappers, see http://is.gd/gdehy'

  s.add_dependency('mongo', ['>= 0.20.1'])

  s.require_paths = ['lib']

  s.files = ['examples/tracks.rb', 'lib/mongo_record.rb',
             'lib/mongo_record/base.rb',
             'lib/mongo_record/core_ext.rb',
             'lib/mongo_record/log_device.rb',
             'lib/mongo_record/sql.rb',
             'lib/mongo_record/subobject.rb',
             'README.rdoc', 'Rakefile',
             'mongo-record.gemspec',
             'LICENSE']
  s.test_files = ['tests/address.rb',
                  'tests/course.rb',
                  'tests/student.rb',
                  'tests/class_in_module.rb',
                  'tests/test_log_device.rb',
                  'tests/test_mongo.rb',
                  'tests/test_sql.rb',
                  'tests/track2.rb',
                  'tests/track3.rb']

  s.has_rdoc = true
  s.rdoc_options = ['--main', 'README.rdoc', '--inline-source']
  s.extra_rdoc_files = ['README.rdoc']

  s.authors = ['Jim Menard', 'Mike Dirolf']
  s.email = ['mongodb-user@googlegroups.com']
  s.homepage = 'http://www.mongodb.org'
end
