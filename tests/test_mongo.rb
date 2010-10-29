# Copyright 2009-2010 10gen, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

$LOAD_PATH[0,0] = File.join(File.dirname(__FILE__), '../lib')
require 'rubygems'
require 'test/unit'
require 'mongo_record'
require File.join(File.dirname(__FILE__), 'course')
require File.join(File.dirname(__FILE__), 'address')
require File.join(File.dirname(__FILE__), 'student')
require File.join(File.dirname(__FILE__), 'class_in_module')

class Track < MongoRecord::Base
  collection_name :tracks
  fields :artist, :album, :song, :track, :created_at

  def to_s
    # Uses both accessor methods and ivars themselves
    "artist: #{artist}, album: #{album}, song: #@song, track: #{@track ? @track.to_i : nil}"
  end
end

# Same class, but this time class.name.downcase == collection name so we don't
# have to call collection_name.
class Rubytest < MongoRecord::Base
  fields :artist, :album, :song, :track
  def to_s
    "artist: #{artist}, album: #{album}, song: #{song}, track: #{track ? track.to_i : nil}"
  end
end

# Class without any fields defined to test inserting custom attributes
class Playlist < MongoRecord::Base
  collection_name :playlists
end

class MongoTest < Test::Unit::TestCase

  @@host = ENV['MONGO_RUBY_DRIVER_HOST'] || 'localhost'
  @@port = ENV['MONGO_RUBY_DRIVER_PORT'] || Mongo::Connection::DEFAULT_PORT
  @@db = Mongo::Connection.new(@@host, @@port).db('mongorecord-test')
  @@students = @@db.collection('students')
  @@courses = @@db.collection('courses')
  @@tracks = @@db.collection('tracks')
  @@playlists = @@db.collection('playlists')

  def setup
    super
    MongoRecord::Base.connection = @@db

    @@students.remove
    @@courses.remove
    @@tracks.remove
    @@playlists.remove

    # Manually insert data without using MongoRecord::Base
    @@tracks.insert({:_id => BSON::ObjectId.new, :artist => 'Thomas Dolby', :album => 'Aliens Ate My Buick', :song => 'The Ability to Swing'})
    @@tracks.insert({:_id => BSON::ObjectId.new, :artist => 'Thomas Dolby', :album => 'Aliens Ate My Buick', :song => 'Budapest by Blimp'})
    @@tracks.insert({:_id => BSON::ObjectId.new, :artist => 'Thomas Dolby', :album => 'The Golden Age of Wireless', :song => 'Europa and the Pirate Twins'})
    @@tracks.insert({:_id => BSON::ObjectId.new, :artist => 'XTC', :album => 'Oranges & Lemons', :song => 'Garden Of Earthly Delights', :track => 1})
    @mayor_id = BSON::ObjectId.new
    @@tracks.insert({:_id => @mayor_id, :artist => 'XTC', :album => 'Oranges & Lemons', :song => 'The Mayor Of Simpleton', :track => 2})
    @@tracks.insert({:_id => BSON::ObjectId.new, :artist => 'XTC', :album => 'Oranges & Lemons', :song => 'King For A Day', :track => 3})

    @mayor_str = "artist: XTC, album: Oranges & Lemons, song: The Mayor Of Simpleton, track: 2"
    @mayor_song = 'The Mayor Of Simpleton'

    @spongebob_addr = Address.new(:street => "3 Pineapple Lane", :city => "Bikini Bottom", :state => "HI", :postal_code => "12345")
    @bender_addr = Address.new(:street => "Planet Express", :city => "New New York", :state => "NY", :postal_code => "10001")
    @course1 = Course.new(:name => 'Introductory Testing')
    @course2 = Course.new(:name => 'Advanced Phlogiston Combuston Theory')
    @score1 = Score.new(:for_course => @course1, :grade => 4.0)
    @score2 = Score.new(:for_course => @course2, :grade => 3.5)
  end

  def teardown
    @@students.remove
    @@courses.remove
    @@tracks.remove
    @@playlists.remove
    super
  end

  def test_ivars_created
    t = Track.new
    %w(_id artist album song track).each { |iv|
      assert t.instance_variable_defined?("@#{iv}")
    }
  end
  
  def test_new_record_set_correctly
    t = Track.new(:_id => 12345, :artist => 'Alice In Chains')
    assert_equal true, t.new_record?
  end

  def test_method_generation
    x = Track.new({:artist => 1, :album => 2})

    assert x.respond_to?(:_id)
    assert x.respond_to?(:artist)
    assert x.respond_to?(:album)
    assert x.respond_to?(:song)
    assert x.respond_to?(:track)
    assert x.respond_to?(:_id=)
    assert x.respond_to?(:artist=)
    assert x.respond_to?(:album=)
    assert x.respond_to?(:song=)
    assert x.respond_to?(:track=)
    assert x.respond_to?(:_id?)
    assert x.respond_to?(:artist?)
    assert x.respond_to?(:album?)
    assert x.respond_to?(:song?)
    assert x.respond_to?(:track?)

    assert_equal(1, x.artist)
    assert_equal(2, x.album)
    assert_nil(x.song)
    assert_nil(x.track)
  end

  def test_dynamic_methods_in_new
    x = Track.new({:foo => 1, :bar => 2})
    y = Track.new({:artist => 3, :song => 4})

    assert x.respond_to?(:_id)
    assert x.respond_to?(:artist)
    assert x.respond_to?(:album)
    assert x.respond_to?(:song)
    assert x.respond_to?(:track)
    assert x.respond_to?(:_id=)
    assert x.respond_to?(:artist=)
    assert x.respond_to?(:album=)
    assert x.respond_to?(:song=)
    assert x.respond_to?(:track=)
    assert x.respond_to?(:_id?)
    assert x.respond_to?(:artist?)
    assert x.respond_to?(:album?)
    assert x.respond_to?(:song?)
    assert x.respond_to?(:track?)
    
    # dynamic fields
    assert x.respond_to?(:foo)
    assert x.respond_to?(:bar)
    assert x.respond_to?(:foo=)
    assert x.respond_to?(:bar=)
    assert x.respond_to?(:foo?)
    assert x.respond_to?(:bar?)
    
    # make sure accessors only per-object
    assert !y.respond_to?(:foo)
    assert !y.respond_to?(:bar)
    assert !y.respond_to?(:foo=)
    assert !y.respond_to?(:bar=)
    assert !y.respond_to?(:foo?)
    assert !y.respond_to?(:bar?)

    assert_equal(1, x.foo)
    assert_equal(2, x.bar)
    assert_nil(x.song)
    assert_nil(x.track)
    assert_equal(3, y.artist)
    assert_equal(4, y.song)
  end

  def test_dynamic_methods_in_find
    @@tracks.insert({:_id => 909, :artist => 'Faith No More', :album => 'Album Of The Year', :song => 'Stripsearch', :track => 2,
                     :vocals => 'Mike Patton', :drums => 'Mike Bordin', :producers => ['Roli Mosimann', 'Billy Gould']})
    x = Track.find_by_id(909)

    # defined
    assert x.respond_to?(:_id)
    assert x.respond_to?(:artist)
    assert x.respond_to?(:album)
    assert x.respond_to?(:song)
    assert x.respond_to?(:track)
    assert x.respond_to?(:_id=)
    assert x.respond_to?(:artist=)
    assert x.respond_to?(:album=)
    assert x.respond_to?(:song=)
    assert x.respond_to?(:track=)
    assert x.respond_to?(:_id?)
    assert x.respond_to?(:artist?)
    assert x.respond_to?(:album?)
    assert x.respond_to?(:song?)
    assert x.respond_to?(:track?)
    
    # dynamic fields
    assert x.respond_to?(:vocals)
    assert x.respond_to?(:drums)
    assert x.respond_to?(:producers)
    assert x.respond_to?(:vocals=)
    assert x.respond_to?(:drums=)
    assert x.respond_to?(:producers=)
    assert x.respond_to?(:vocals?)
    assert x.respond_to?(:drums?)
    assert x.respond_to?(:producers?)

    assert_equal 'Faith No More', x.artist
    assert_equal 'Album Of The Year', x.album
    assert_equal 'Stripsearch', x.song
    assert_equal 2, x.track
    assert_equal 'Mike Patton', x.vocals
    assert_equal 'Mike Bordin', x.drums
    assert_equal ['Roli Mosimann', 'Billy Gould'], x.producers
    
    x.destroy
  end
  
  def test_initialize_block
    track = Track.new { |t|
      t.artist = "Me'Shell Ndegeocello"
      t.album = "Peace Beyond Passion"
      t.song = "Bittersweet"
    }
    assert_equal "Me'Shell Ndegeocello", track.artist
    assert_equal "Peace Beyond Passion", track.album
    assert_equal "Bittersweet", track.song
    assert !track.track?
  end

  def test_find_by_id
    assert_equal(@mayor_str, Track.find_by_id(@mayor_id).to_s)
  end

  def test_find_by_custom_id
    @@tracks.insert({:_id => 25, :artist => 'Mike D', :album => 'Awesome Blossom', :song => 'Hello World', :track => 5})
    assert_equal("artist: Mike D, album: Awesome Blossom, song: Hello World, track: 5",
                 Track.find_by_id(25).to_s)

  end

  def test_find_by_song
    assert_equal("artist: Thomas Dolby, album: Aliens Ate My Buick, song: Budapest by Blimp, track: ", Track.find_by_song('Budapest by Blimp').to_s)
  end

  def test_update
    count = @@tracks.count()
    t = Track.find_by_track(2)
    t.track = 99
    t.save
    str = @mayor_str.sub(/2/, '99')
    assert_equal(str, t.to_s)
    assert_equal(str, Track.find_by_track(99).to_s)
    assert_equal(count, @@tracks.count())
  end

  def test_find_all
    assert_all_songs Track.find(:all).inject('') { |str, t| str + t.to_s }
  end

  def test_find_using_hash
    str = Track.find(:all, :conditions => {:album => 'Aliens Ate My Buick'}).inject('') { |str, t| str + t.to_s }
    assert_match(/song: The Ability to Swing/, str)
    assert_match(/song: Budapest by Blimp/, str)
  end

  def test_find_first
    t = Track.find(:first)
    assert t.kind_of?(Track)
    str = t.to_s
    assert_match(/artist: [^,]+,/, str, "did not find non-empty artist name")
  end

  def test_find_first_with_search
    t = Track.find(:first, :conditions => {:track => 3})
    assert_not_nil t, "oops: nil track returned"
    assert_equal "artist: XTC, album: Oranges & Lemons, song: King For A Day, track: 3", t.to_s
  end

  def test_find_first_returns_nil_if_not_found
    assert_nil Track.find(:first, :conditions => {:track => 666})
  end

  def test_find_all_by
    str = Track.find_all_by_album('Oranges & Lemons').inject('') { |str, t| str + t.to_s }
    assert_match(/song: Garden Of Earthly Delights/, str)
    assert_match(/song: The Mayor Of Simpleton/, str)
    assert_match(/song: King For A Day/, str)
  end

  def test_find_using_hash_with_array_and_range
    sorted_track_titles = ['Garden Of Earthly Delights', 'King For A Day', @mayor_song]

    # Array
    list = Track.find(:all, :conditions => {:track => [1,2,3]}).to_a
    assert_equal 3, list.length
    assert_equal sorted_track_titles, list.collect{|t| t.song}.sort

    # Range
    list = Track.find(:all, :conditions => {:track => 1..3}).to_a
    assert_equal 3, list.length
    assert_equal sorted_track_titles, list.collect{|t| t.song}.sort
  end

  def test_new_no_arg
    assert_equal "artist: , album: , song: , track: ", Track.new.to_s
  end

  def test_new_by_hash
    assert_equal("artist: Level 42, album: Standing In The Light, song: Micro-Kid, track: 1",
                 Track.new(:song => 'Micro-Kid', :album => 'Standing In The Light', :artist => 'Level 42', :track => 1).to_s)
  end

  def test_new_and_save
    x = Track.new(:artist => 'Level 42', :album => 'Standing In The Light', :song => 'Micro-Kid', :track => 1)
    assert_nil(x.id)
    assert x.save, "x.save returned false; expected true"
    x = Track.last
    assert_not_nil(x.id)
    z = Track.find(x.id)
    assert_equal(x.to_s, z.to_s)
    assert_equal(x.id, z.id)
  end

  def test_find_with_hint
    @@tracks.create_index([['artist', 1]])
    assert_equal "BtreeCursor artist_1",
      Track.find(:all, :conditions => {:artist => 'XTC'}).explain["cursor"]

    assert_equal "BasicCursor",
      Track.find(:all, :hint => {'$natural' => 1},
                 :conditions => {:artist => 'XTC'}).explain["cursor"]
  end

  def test_find_or_create_but_already_exists
    assert_equal("artist: Thomas Dolby, album: Aliens Ate My Buick, song: The Ability to Swing, track: ",
                 Track.find_or_create_by_song('The Ability to Swing', :artist => 'ignored because song found').to_s)
  end

  def test_find_or_create_new_created
    assert_equal("artist: New Artist, album: New Album, song: New Song, track: ",
                 Track.find_or_create_by_song('New Song', :artist => 'New Artist', :album => 'New Album').to_s)
  end

  def test_cursor_methods
    assert_equal 2, Track.find(:all, :limit => 2).to_a.length
  end

  def test_return_nil_if_no_match
    assert_nil Track.find(:first, :conditions => {:song => 'Does Not Compute'})
  end

  def test_raise_error_if_bogus_id
    Track.find("bogus_id")
    fail 'expected "find Track with ID=bogus_id" exception'
  rescue => ex
    assert_match /find Track with ID=bogus_id/, ex.to_s
  end

  def test_raise_error_if_first_and_bogus_id_in_hash
    Track.find(:first, :conditions => {:_id => "bogus_id"})
    fail 'expected "find Track with ID=bogus_id" exception'
  rescue => ex
    assert_match /find Track with ID=bogus_id/, ex.to_s
  end

  def test_find_options
    assert_equal 2, Track.find(:all, :limit => 2).to_a.length
  end

  def test_order_options
    tracks = Track.find(:all, :order => "song asc")
    assert_not_nil tracks
    assert_equal "Budapest by Blimp:Europa and the Pirate Twins:Garden Of Earthly Delights:King For A Day:The Ability to Swing:The Mayor Of Simpleton",
                 tracks.collect {|t| t.song }.join(':')

    tracks = Track.find(:all, :order => "artist desc, song")
    assert_not_nil tracks
    assert_equal "Garden Of Earthly Delights:King For A Day:The Mayor Of Simpleton:Budapest by Blimp:Europa and the Pirate Twins:The Ability to Swing", tracks.collect {|t| t.song }.join(':')
  end

  def test_delete
    Track.find(:first, :conditions => {:song => 'King For A Day'}).delete
    str = Track.find(:all).inject('') { |str, t| str + t.to_s }
    assert_match(/song: The Ability to Swing/, str)
    assert_match(/song: Budapest by Blimp/, str)
    assert_match(/song: Europa and the Pirate Twins/, str)
    assert_match(/song: Garden Of Earthly Delights/, str)
    assert_match(/song: The Mayor Of Simpleton/, str)
    assert_no_match(/song: King For A Day/, str)
  end

  def test_class_delete
    Track.delete(@mayor_id)
    assert_no_match(/song: The Mayor Of Simpleton/, Track.find(:all).inject('') { |str, t| str + t.to_s })
  end

  def test_update_all
    Track.update_all({:track => 919}, {:artist => 'XTC'})
    Track.all.each{|r| assert_equal(919, r.track) if r.artist == 'XTC' }

    # Should fail (can't $inc/$set) - remove this test once Mongo 1.2 is out
    error = nil
    begin
      Track.update_all({:song => 'Just Drums'}, {}, :safe => true)
    rescue Mongo::OperationFailure => error
    end
    assert_instance_of Mongo::OperationFailure, error 

    @@tracks.drop_index 'song_-1'  # otherwise update_all $set fails
    Track.update_all({:song => 'Just Drums'}, {}, :safe => true)

    assert_no_match(/song: Budapest by Blimp/, Track.all.inject('') { |str, t| str + t.to_s })

    assert_equal 6, Track.count
  end

  def test_delete_all
    Track.delete_all({:artist => 'XTC'})
    assert_no_match(/artist: XTC/, Track.find(:all).inject('') { |str, t| str + t.to_s })

    Track.delete_all(["song = ?", 'The Mayor Of Simpleton'])
    assert_no_match(/song: The Mayor Of Simpleton/, Track.find(:all).inject('') { |str, t| str + t.to_s })

    Track.delete_all("song = 'King For A Day'")
    assert_no_match(/song: King For A Day/, Track.find(:all).inject('') { |str, t| str + t.to_s })

    Track.delete_all()
    assert_equal 0, Track.count
  end

  def test_find_by_mql_not_implemented
    Track.find_by_mql("")
    fail "should have raised a 'not implemented' exception"
  rescue => ex
    assert_equal("not implemented", ex.to_s)
  end

  def test_count
    assert_equal 6, Track.count
    assert_equal 3, Track.count(:conditions => {:artist => 'XTC'})
  end

  def test_count_collection_missing
    @@db.drop_collection('tracks')
    assert_equal 0, Track.count
  end

  def test_select
    str = Track.find(:all, :select => :album).inject('') { |str, t| str + t.to_s }
    assert str.include?("artist: , album: Oranges & Lemons, song: , track:")
  end

  def test_find_using_id
    t = Track.find_by_song('King For A Day')
    tid = t._id
    # first is string id, second is ObjectId
    records = Track.find([@mayor_id, tid]).to_a
    assert_equal 2, records.size
  end

  def test_find_one_using_id
    t = Track.find(@mayor_id)
    assert_not_nil t
    assert_match /song: The Mayor Of Simpleton/, t.to_s
  end

  def test_select_find_by_id
    t = Track.find(@mayor_id, :select => :album)
    assert t.album?
    assert !t.artist?
    assert !t.song?
    assert !t.track?
    assert_equal "artist: , album: Oranges & Lemons, song: , track: ", t.to_s
  end

  def test_has_one_initialize
    s = Student.new(:name => 'Spongebob Squarepants', :email => 'spongebob@example.com', :address => @spongebob_addr)

    assert_not_nil s.address, "Address not set correctly in Student#initialize"
    assert_equal '3 Pineapple Lane', s.address.street
  end

  def test_has_one_save_and_find
    s = Student.new(:name => 'Spongebob Squarepants', :email => 'spongebob@example.com', :address => @spongebob_addr)
    s.save

    s2 = Student.find(:first)
    assert_equal 'Spongebob Squarepants', s2.name
    assert_equal 'spongebob@example.com', s2.email
    a2 = s2.address
    assert_not_nil a2
    assert_kind_of Address, a2
    assert_equal @spongebob_addr.street, a2.street
    assert_equal @spongebob_addr.city, a2.city
    assert_equal @spongebob_addr.state, a2.state
    assert_equal @spongebob_addr.postal_code, a2.postal_code
  end

  def test_student_array_field
    s = Student.new(:name => 'Spongebob Squarepants', :email => 'spongebob@example.com', :num_array => [100, 90, 80])
    s.save

    s2 = Student.find(:first)
    assert_equal [100, 90, 80], s2.num_array
  end

  def test_has_many_initialize
    s = Student.new(:name => 'Spongebob Squarepants', :email => 'spongebob@example.com', :scores => [@score1, @score2])
    assert_not_nil s.scores
    assert_equal 2, s.scores.length
    assert_equal @score1, s.scores[0]
    assert_equal @score2, s.scores[1]
  end

  def test_has_many_initialize_one_value
    s = Student.new(:name => 'Spongebob Squarepants', :email => 'spongebob@example.com', :scores => @score1)
    assert_not_nil s.scores
    assert_equal 1, s.scores.length
    assert_equal @score1, s.scores[0]
  end

  def test_has_many_save_and_find
    s = Student.new(:name => 'Spongebob Squarepants', :email => 'spongebob@example.com', :scores => [@score1, @score2])
    s.save!
    assert_not_nil s.id

    assert_equal 1, Student.count()
    s2 = Student.find(:first)
    assert_equal 'Spongebob Squarepants', s2.name
    assert_equal 'spongebob@example.com', s2.email
    list = s2.scores
    assert_not_nil list
    assert_equal 2, list.length
    score = list.first
    assert_not_nil score
    assert_kind_of Score, score
    assert (score.for_course.name == @score1.for_course.name && score.grade == @score1.grade), "oops: first score is wrong: #{score}"
  end

  def test_has_many_class_in_module
    a1 = MyMod::A.new(:something => 4)
    a2 = MyMod::A.new(:something => 10)
    b = B.new(:a => [a1, a2])
    assert_not_nil b.a
    assert_equal 2, b.a.length
    assert_equal a1, b.a[0]
    assert_equal a2, b.a[1]
  end

  def test_field_query_methods
    s = Student.new(:name => 'Spongebob Squarepants', :email => 'spongebob@example.com', :scores => [@score1, @score2])
    assert s.name?
    assert s.email?
    assert s.scores

    s = Student.new(:name => 'Spongebob Squarepants')
    assert s.name?
    assert !s.email?
    assert !s.scores?

    s.email = ''
    assert !s.email?
  end

  def test_new_record
    t = Track.new
    assert_nil t.id
    assert t.new_record?
    t.save
    assert_not_nil t.id
    assert !t.new_record?

    t = Track.create(:artist => 'Level 42', :album => 'Standing In The Light', :song => 'Micro-Kid', :track => 1)
    assert !t.new_record?

    t = Track.find(:first)
    assert !t.new_record?

    t = Track.find_or_create_by_song('New Song', :artist => 'New Artist', :album => 'New Album')
    assert !t.new_record?

    t = Track.find_or_initialize_by_song('Newer Song', :artist => 'Newer Artist', :album => 'Newer Album')
    assert t.new_record?
  end

  def test_sql_parsing
    t = Track.find(:first, :conditions => "song = '#{@mayor_song}'")
    assert_equal @mayor_str, t.to_s
  end

  def test_sql_substitution
    s = @mayor_song
    t = Track.find(:first, :conditions => ["song = ?", s])
    assert_equal @mayor_str, t.to_s
  end

  def test_sql_named_substitution
    t = Track.find(:first, :conditions => ["song = :song", {:song => @mayor_song}])
    assert_equal @mayor_str, t.to_s
  end

  def test_sql_like
    t = Track.find(:first, :conditions => "song like '%Simp%'")
    assert_equal @mayor_str, t.to_s
  end

  def test_sql_in
    str = Track.find(:all, :conditions => "song in ('#{@mayor_song}', 'King For A Day')").inject('') { |str, t| str + t.to_s }
    assert str.include?(@mayor_song)
    assert str.include?('King For A Day')

    list = Track.find(:all, :conditions => "track in (1,2,3)").to_a
    assert_equal 3, list.length
    assert_equal ['Garden Of Earthly Delights', 'King For A Day', @mayor_song], list.collect{|t| t.song}.sort
  end

  def test_in_array
    str = Track.find(:all, :conditions => ["song in (?)", [@mayor_song, 'King For A Day']]).inject('') { |str, t| str + t.to_s }
    assert str.include?(@mayor_song)
    assert str.include?('King For A Day')
  end

  def test_in_array_rails_syntax
    str = Track.find(:all, :conditions => {:song => [@mayor_song, 'King For A Day']}).inject('') { |str, t| str + t.to_s }
    assert str.include?(@mayor_song)
    assert str.include?('King For A Day')
  end

  def test_in_named_array
    str = Track.find(:all, :conditions => ["song in (:songs)", {:songs => [@mayor_song, 'King For A Day']}]).inject('') { |str, t| str + t.to_s }
    assert str.include?(@mayor_song)
    assert str.include?('King For A Day')
  end

  def test_where
    # function
    str = Track.find(:all, :where => "function() { return obj.song == '#{@mayor_song}'; }").inject('') { |str, t| str + t.to_s }
    assert_equal @mayor_str, str

    # expression
    str = Track.find(:all, :where => "obj.song == '#{@mayor_song}'").inject('') { |str, t| str + t.to_s }
    assert_equal @mayor_str, str
  end

  def test_destroy
    Track.destroy(@mayor_id)
    begin
      Track.find(@mayor_id)
      fail "expected exception about missing ID"
    rescue => ex
      assert_match /Couldn't find Track with ID=#@mayor_id/, ex.to_s # ' <= for Emacs font lock mode
    end
  end

  # Potential bug: if this test runs at midnight, a create runs before midnight
  # and the update runs after, then this test will fail.
  def test_time_updates
    s = Student.new(:name => 'Spongebob Squarepants')
    assert s.instance_variable_defined?(:@created_at)

    assert !s.created_at?
    assert !s.created_on?
    assert !s.updated_on?

    s.save
    assert s.created_at?
    assert_kind_of Time, s.created_at
    assert s.created_on?
    assert_kind_of Time, s.created_on
    assert !s.updated_on?
    t = Time.now
    assert_equal Time.local(t.year, t.month, t.day), s.created_on

    s.save
    assert s.created_at?
    assert s.created_on?
    assert s.updated_on?
    assert_kind_of Time, s.created_at
    assert_equal s.created_on, s.updated_on
  end

  # This reproduces a bug where DBRefs weren't being created properly because
  # the MongoRecord::Base objects weren't storing _ns
  def test_db_ref
    s = Student.new(:name => 'Spongebob Squarepants', :address => @spongebob_addr)
    s.save

    @course1.save
    assert_not_nil @course1.id
    assert_not_nil @course1["_ns"]

    s.add_score(@course1.id, 3.5)
    s.save

    score = s.scores.first
    assert_not_nil score
    assert_equal @course1.name, score.for_course.name

    # Now change the name of @course1 and see the student's score's course
    # name change.
    @course1.name = 'changed'
    @course1.save

    s = Student.find(:first, :conditions => "name = 'Spongebob Squarepants'")
    assert_not_nil s
    assert_equal 1, s.scores.length
    assert_equal 'changed', s.scores.first.for_course.name


    # Now try with has_many
    score.save
    s.scores = [score]
    s.save

    assert_equal 3.5, s.scores.first.grade

    s = Student.find(:first, :conditions => "name = 'Spongebob Squarepants'")
    assert_not_nil s
    assert_equal 1, s.scores.length
    assert_equal 3.5, s.scores.first.grade

    score.grade = 4.0
    score.save

    s = Student.find(:first, :conditions => "name = 'Spongebob Squarepants'")
    assert_not_nil s
    assert_equal 1, s.scores.length
    assert_equal 4.0, s.scores.first.grade
  end

  def test_subobjects_have_no_ids
    @spongebob_addr.id
  rescue => ex
    assert_match /Subobjects don't have ids/, ex.to_s # ' <= for Emacs font-lock mode
  end

  def test_can_not_save_subobject
    @spongebob_addr.save
    fail "expected failed save of address"
  rescue => ex
    assert_match /Subobjects/, ex.to_s
  end

  def test_alternate_connection
    old_db = MongoRecord::Base.connection
    assert_equal @@db, old_db
    alt_db = Mongo::Connection.new(@@host, @@port).db('mongorecord-test-alt-conn')
    assert_not_equal old_db, alt_db
    alt_db.drop_collection('students')
    begin
      @@db = nil
      MongoRecord::Base.connection = alt_db
      assert_equal alt_db, MongoRecord::Base.connection

      # Make sure collection exists
      coll = alt_db.collection('students')
      coll.insert('name' => 'foo')
      coll.remove

      assert_equal 0, coll.count()
      s = Student.new(:name => 'Spongebob Squarepants', :address => @spongebob_addr)
      assert s.save, "save failed"
      assert_equal 1, coll.count()
    ensure
      @@db = old_db
      MongoRecord::Base.connection = @@db
      alt_db.drop_collection('students')
    end
  end

  def test_method_missing
    begin
      Track.foobar
      fail "expected 'undefined method' exception"
    rescue => ex
      assert_match /undefined method \`foobar\' for Track:Class/, ex.to_s
    end
  end

  def test_adding_custom_attributes
    s = Student.new(:silly_name => 'Yowza!')
    s.save
    s = Student.last
    assert_equal s.silly_name, 'Yowza!'
  end

  def assert_all_songs(str)
    assert_match(/song: The Ability to Swing/, str)
    assert_match(/song: Budapest by Blimp/, str)
    assert_match(/song: Europa and the Pirate Twins/, str)
    assert_match(/song: Garden Of Earthly Delights/, str)
    assert_match(/song: The Mayor Of Simpleton/, str)
    assert_match(/song: King For A Day/, str)
  end


  #################


  def test_find_all_alias
    assert_all_songs Track.all.inject('') { |str, t| str + t.to_s }
  end

  def test_find_first_alias
    t = Track.first
    assert t.kind_of?(Track)
    str = t.to_s
    assert_match(/artist: [^,]+,/, str, "did not find non-empty artist name")
  end

  def test_find_last
    c = Course.new(:name=>"History")
    c.save
    assert_equal Course.last.name, "History"
  end

  def test_new_and_save_custom_attributes
    x = Playlist.new(:artist => 'Level 42', :album => 'Standing In The Light', :song => 'Micro-Kid', :track => 1)
    assert_nil(x.id)
    x.save
    x = Playlist.last
    assert_not_nil(x.id)
    assert_equal(x.artist, "Level 42")
    assert_not_nil(x.created_at)
    assert_not_nil(x.created_on)
  end

  def test_update_for_custom_attributes
    p = Playlist.create(:artist => "The Beatles", :song => "Jailhouse Rock")
    count = Playlist.count
    p = Playlist.last
    assert_equal(p.artist, "The Beatles")
    p.artist = "Elvis"
    p.save
    assert_not_nil(p.updated_at)
    assert_not_nil(p.updated_on)
    assert_equal(count, Playlist.count)
  end


  def test_update_attributes
    opts = {:artist => 'Bon Jovi', :album => 'Slippery When Wet', :song => 'Livin On A Prayer'}
    track = Track.new
    track.update_attributes(opts)
    t = Track.find_by_artist("Bon Jovi")
    assert_equal(t.album, "Slippery When Wet")
  end

  def test_update_attributes_for_custom_attributes
    opts = {:artist => 'The Outfield', :album => 'Play Deep', :song => 'Your Love', :year => 1986}
    playlist = Playlist.new
    playlist.update_attributes(opts)

    # We *want* the following to fail, because otherwise MongoRecord is buggy in the following
    # situation:
    #
    #    Rails/Sinatra/etc server instance #1 does: playlist.custom_field = 'foo'
    #    Rails/Sinatra/etc instance #2 attempts to do: Playlist.find_by_custom_field
    #
    # This will fail because, in previous versions of MongoRecord, the instance would callback
    # into class.field(), the changing the class definition, then use this modified definition to
    # determine whether dynamic finders work.
    #
    # The biggest issue is you'll never catch this in dev, since everything is a single instance
    # in memory.  It will manifest as mysterious "undefined method" production bugs.  As such, we *must*
    # restrict dynamic accessors to only modifying the instance for each row, or else they corrupt
    # the class.  This means find_by_whatever only works for fields defined via fields()
    error = nil
    begin
      p = Playlist.find_by_artist("The Outfield")
    rescue NoMethodError => error
    end
    assert_instance_of NoMethodError, error

    # This should work though
    p = Playlist.first(:conditions => {:artist => 'The Outfield'})
    assert_equal(p.year, 1986)
  end

  def test_custom_id
    track = Track.new
    track.id = 123
    track.artist = "Nickleback"
    track.song = "Rockstar"
    track.save
    p = Track.find(123)
    assert_equal p.artist, "Nickleback"
  end

  def test_sum
    Course.create(:name=>"Math", :student_count=>10)
    Course.create(:name=>"Science", :student_count=>20)
    assert_equal Course.sum("student_count"), 30
  end

  def test_indexing
    Track.index :artist
    Track.index [:artist, :created_at]
    Track.index [:song, :desc], :unique => true
    Track.index [:artist, [:album, :desc]]
    Track.index [:created_at, Mongo::ASCENDING]

    assert Track.indexes.has_key?("artist_1")
    assert Track.indexes.has_key?("artist_1_created_at_1")
    assert Track.indexes.has_key?("song_-1")
    assert Track.indexes.has_key?("artist_1_album_-1")
    assert Track.indexes.has_key?("created_at_1")
  end

  def test_subobject_create
    Address.create(:street => "3 Pineapple Lane", :city => "Bikini Bottom", :state => "HI", :postal_code => "12345")
    fail "expected can't create exception"
  rescue => ex
    assert_match /Subobjects can't be created/, ex.to_s
  end

end
