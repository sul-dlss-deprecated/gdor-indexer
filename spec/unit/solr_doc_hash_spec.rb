require 'spec_helper'

describe GDor::Indexer::SolrDocHash do
  context "#field_present?" do
    
    context "actual field value is boolean true" do
      it "true if expected value is nil" do
        GDor::Indexer::SolrDocHash.new({:a => true}).field_present?(:a).should == true
      end
      it "false if expected value is String" do
        GDor::Indexer::SolrDocHash.new({:a => true}).field_present?(:a, 'true').should == false
      end
      it "false if expected value is Regex" do
        GDor::Indexer::SolrDocHash.new({:a => true}).field_present?(:a => /true/).should == false
      end
    end

    context "expected value is nil" do
      it "false if the field is not in the doc_hash" do
        GDor::Indexer::SolrDocHash.new({}).field_present?(:any).should == false
      end
      it "false if hash[field] is nil" do
        GDor::Indexer::SolrDocHash.new({:foo => nil}).field_present?(:foo).should == false
      end
      it "false if hash[field] is an empty String" do
        GDor::Indexer::SolrDocHash.new({:foo => ""}).field_present?(:foo).should == false
      end
      it "true if hash[field] is a non-empty String" do
        GDor::Indexer::SolrDocHash.new({:foo => 'bar'}).field_present?(:foo).should == true
      end
      it "false if hash[field] is an empty Array" do
        GDor::Indexer::SolrDocHash.new({:foo => []}).field_present?(:foo).should == false
      end
      it "false if hash[field] is an Array with only empty String values" do
        GDor::Indexer::SolrDocHash.new({:foo => ["", ""]}).field_present?(:foo).should == false
      end
      it "false if hash[field] is an Array with only nil String values" do
        GDor::Indexer::SolrDocHash.new({:foo => [nil]}).field_present?(:foo).should == false
      end
      it "true if hash[field] is a non-empty Array" do
        GDor::Indexer::SolrDocHash.new({:foo => ["a"]}).field_present?(:foo).should == true
      end
      it "false if doc_hash[field] is not a String or Array" do
        GDor::Indexer::SolrDocHash.new({:foo => {}}).field_present?(:foo).should == false
      end
    end
    
    context "expected value is a String" do
      it "true if hash[field] is a String and matches" do
        GDor::Indexer::SolrDocHash.new({:foo => "a"}).field_present?(:foo, 'a').should == true
      end
      it "false if hash[field] is a String and doesn't match" do
        GDor::Indexer::SolrDocHash.new({:foo => "a"}).field_present?(:foo, 'b').should == false
      end
      it "true if hash[field] is an Array with a value that matches" do
        GDor::Indexer::SolrDocHash.new({:foo => ["a", "b"]}).field_present?(:foo, 'a').should == true
      end
      it "false if hash[field] is an Array with no value that matches" do
        GDor::Indexer::SolrDocHash.new({:foo => ["a", "b"]}).field_present?(:foo, 'c').should == false
      end
      it "false if hash[field] is not a String or Array" do
        GDor::Indexer::SolrDocHash.new({:foo => {}}).field_present?(:foo, 'a').should == false
      end
    end
    
    context "expected value is Regex" do
      it "true if hash[field] is a String and matches" do
        GDor::Indexer::SolrDocHash.new({:foo => "aba"}).field_present?(:foo, /b/).should == true
      end
      it "false if hash[field] is a String and doesn't match" do
        GDor::Indexer::SolrDocHash.new({:foo => "aaaaa"}).field_present?(:foo, /b/).should == false
      end
      it "true if hash[field] is an Array with a value that matches" do
        GDor::Indexer::SolrDocHash.new({:foo => ["a", "b"]}).field_present?(:foo, /b/).should == true
      end
      it "false if hash[field] is an Array with no value that matches" do
        GDor::Indexer::SolrDocHash.new({:foo => ["a", "b"]}).field_present?(:foo, /c/).should == false
      end
      it "false if hash[field] is not a String or Array" do
        GDor::Indexer::SolrDocHash.new({:foo => {}}).field_present?(:foo, /a/).should == false
      end
    end
  end # field_present?


  context "#combine" do
    context "orig has no key" do
      subject do
        GDor::Indexer::SolrDocHash.new({})
      end

      it "result has no key if new value is nil" do
        subject.combine({:foo => nil}).should == {}
      end
      it "result has no key if new value is empty String" do
        subject.combine({:foo => ""}).should == {}
      end
      it "result has new value if new value is non-empty String" do
        subject.combine({:foo => 'bar'}).should == {:foo => 'bar'}
      end
      it "result has no key if new value is empty Array" do
        subject.combine({:foo => []}).should == {}
      end
      it "result has new value new value is non-empty Array" do
        subject.combine({:foo => ['bar']}).should == {:foo => ['bar']}
      end
      it "result has no key if new value is not String or Array" do
        subject.combine({:foo => {}}).should == {}
      end
    end # orig has no key
    context "orig value is nil" do
      subject do
        GDor::Indexer::SolrDocHash.new(:foo => nil)
      end
      it "result has no key if new value is nil" do
        subject.combine({:foo => nil}).should == {}
      end
      it "result has no key if new value is empty String" do
        subject.combine({:foo => ""}).should == {}
      end
      it "result has new value if new value is non-empty String" do
        subject.combine({:foo => 'bar'}).should == {:foo => 'bar'}
      end
      it "result has no key if new value is empty Array" do
        subject.combine({:foo => []}).should == {}
      end
      it "result has new value if new value is non-empty Array" do
        subject.combine({:foo => ['bar']}).should == {:foo => ['bar']}
      end
      it "result has no key if new value is not String or Array" do
        subject.combine({:foo => {}}).should == {}
      end
    end # orig value is nil
    context "orig value is empty String" do
      subject do
        GDor::Indexer::SolrDocHash.new(:foo => "")
      end
      it "result has no key if new value is nil" do
        subject.combine({:foo => nil}).should == {}
      end
      it "result has no key if new value is empty String" do
        subject.combine({:foo => ""}).should == {}
      end
      it "result has new value if new value is non-empty String" do
        subject.combine({:foo => 'bar'}).should == {:foo => 'bar'}
      end
      it "result has no key if new value is empty Array" do
        subject.combine({:foo => []}).should == {}
      end
      it "result has new value if new value is non-empty Array" do
        subject.combine({:foo => ['bar']}).should == {:foo => ['bar']}
      end
      it "result has no key if new value is not String or Array" do
        subject.combine({:foo => {}}).should == {}
      end
    end # orig value is empty String
    context "orig value is non-empty String" do
      subject do
        GDor::Indexer::SolrDocHash.new(:foo => "a")
      end
      it "result is orig value if new value is nil" do
        subject.combine({:foo => nil}).should == {:foo => "a"}
      end
      it "result is orig value if new value is empty String" do
        subject.combine({:foo => ""}).should == {:foo => "a"}
      end
      it "result is Array of old and new values if new value is non-empty String" do
        subject.combine({:foo => 'bar'}).should == {:foo => ["a", 'bar']}
      end
      it "result is orig value if new value is empty Array" do
        subject.combine({:foo => []}).should == {:foo => "a"}
      end
      it "result Array of old and new values if new value is non-empty Array" do
        subject.combine({:foo => ['bar', 'ness']}).should == {:foo => ["a", 'bar', 'ness']}
      end
      it "result is orig value if new value is not String or Array" do
        subject.combine({:foo => :bar}).should == {:foo => "a"}
      end
    end # orig value is String
    context "orig value is empty Array" do
      subject do
        GDor::Indexer::SolrDocHash.new(:foo => [])
      end
      it "result has no key if new value is nil" do
        subject.combine({:foo => nil}).should == {}
      end
      it "result has no key if new value is empty String" do
        subject.combine({:foo => ""}).should == {}
      end
      it "result is new value if new value is non-empty String" do
        subject.combine({:foo => 'bar'}).should == {:foo => 'bar'}
      end
      it "result has no key if new value is empty Array" do
        subject.combine({:foo => []}).should == {}
      end
      it "result is new values if new value is non-empty Array" do
        subject.combine({:foo => ['bar', 'ness']}).should == {:foo => ['bar', 'ness']}
      end
      it "result has no key if new value is not String or Array" do
        subject.combine({:foo => {}}).should == {}
      end
    end # orig value is empty Array
    context "orig value is non-empty Array" do
      subject do
        GDor::Indexer::SolrDocHash.new(:foo => ["a", "b"])
      end
      it "result is orig value if new value is nil" do
        subject.combine({:foo => nil}).should == {:foo => ["a", "b"]}
      end
      it "result is orig value if new value is empty String" do
        subject.combine({:foo => ""}).should == {:foo => ["a", "b"]}
      end
      it "result is Array of old and new values if new value is non-empty String" do
        subject.combine({:foo => 'bar'}).should == {:foo => ["a", "b", 'bar']}
      end
      it "result is orig value if new value is empty Array" do
        subject.combine({:foo => []}).should == {:foo => ["a", "b"]}
      end
      it "result Array of old and new values if new value is non-empty Array" do
        subject.combine({:foo => ['bar', 'ness']}).should == {:foo => ["a", "b", 'bar', 'ness']}
      end
      it "result is orig value if new value is not String or Array" do
        subject.combine({:foo => :bar}).should == {:foo => ["a", "b"]}
      end
    end # orig value is non-empty Array
  end # combine

  context "#validate_item" do
    let(:collection_druid) { "xyz" }
    let(:mock_config) { { default_set: "is_member_of_collection_#{collection_druid}" } }

    before do
      GDor::Indexer::SolrDocHash.any_instance.stub(validate_gdor_fields: [])
    end

    it "should call validate_gdor_fields" do
      hash = GDor::Indexer::SolrDocHash.new({})
      hash.should_receive(:validate_gdor_fields).and_return([])
      hash.validate_item(mock_config)
    end
    it "should have a value if collection is wrong" do
      hash = GDor::Indexer::SolrDocHash.new({
        :collection => 'junk',
        :collection_with_title => "#{collection_druid}-|-asdasdf",
        :file_id => ['anything']
      })
      hash.should_receive(:validate_gdor_fields).and_return([])
      hash.validate_item(mock_config).first.should =~ /collection /
    end
    it "should have a value if collection_with_title is missing" do
      hash = GDor::Indexer::SolrDocHash.new({
        :collection => collection_druid,
        :collection_with_title => nil,
        :file_id => ['anything']
      })
      hash.validate_item(mock_config).first.should =~ /collection_with_title /
    end
    it "should have a value if collection_with_title is missing the title" do
      hash = GDor::Indexer::SolrDocHash.new({
        :collection => collection_druid,
        :collection_with_title => "#{collection_druid}-|-",
        :file_id => ['anything']
      })
      hash.validate_item(mock_config).first.should =~ /collection_with_title /
    end
    it "should have a value if file_id field is missing" do
      hash = GDor::Indexer::SolrDocHash.new({
        :collection => collection_druid,
        :collection_with_title => "#{collection_druid}-|-asdasdf",
        :file_id => nil
      })
      hash.validate_item(mock_config).first.should =~ /file_id/
    end
    it "should not have a value if gdor_fields and item fields are ok" do
      hash = GDor::Indexer::SolrDocHash.new({
        :collection => collection_druid,
        :collection_with_title => "#{collection_druid}-|-asdasdf",
        :file_id => ['anything']
      })
      hash.validate_item(mock_config).should == []
    end
  end # validate_item

  context "#validate_collection" do
    let(:mock_config) { { } }

    before do
      GDor::Indexer::SolrDocHash.any_instance.stub(validate_gdor_fields: [])
    end

    it "should call validate_gdor_fields" do
      hash = GDor::Indexer::SolrDocHash.new({})
      hash.should_receive(:validate_gdor_fields).and_return([])
      hash.validate_collection(mock_config)
    end
    it "should have a value if collection_type is missing" do
      hash = GDor::Indexer::SolrDocHash.new({:format_main_ssim => 'Archive/Manuscript'})

      hash.validate_collection(mock_config).first.should =~ /collection_type/
    end
    it "should have a value if collection_type is not 'Digital Collection'" do
      hash = GDor::Indexer::SolrDocHash.new({:collection_type => 'lalalalala', :format_main_ssim => 'Archive/Manuscript'})
      hash.validate_collection(mock_config).first.should =~ /collection_type/
    end
    it "should have a value if format_main_ssim is missing" do
      hash = GDor::Indexer::SolrDocHash.new({:collection_type => 'Digital Collection'})
      hash.validate_collection(mock_config).first.should =~ /format_main_ssim/
    end
    it "should have a value if format_main_ssim doesn't include 'Archive/Manuscript'" do
      hash = GDor::Indexer::SolrDocHash.new({:format_main_ssim => 'lalalalala', :collection_type => 'Digital Collection'})
      hash.validate_collection(mock_config).first.should =~ /format_main_ssim/
    end
    it "should not have a value if gdor_fields, collection_type and format_main_ssim are ok" do
      hash = GDor::Indexer::SolrDocHash.new({:collection_type => 'Digital Collection', :format_main_ssim => 'Archive/Manuscript'})
      hash.validate_collection(mock_config).should == []
    end
  end # validate_collection

  context "#validate_gdor_fields" do
    let(:druid) { 'druid' }
    let(:purl_url) { 'http://some.uri' }
    let(:mock_config) { double purl: purl_url }

    it "should return an empty Array when there are no problems" do
      hash = GDor::Indexer::SolrDocHash.new({
        :access_facet => 'Online',
        :druid => druid,
        :url_fulltext => "#{purl_url}/#{druid}",
        :display_type => 'image',
        :building_facet => 'Stanford Digital Repository'})
      hash.validate_gdor_fields(mock_config).should == []
    end
    it "should have a value for each missing field" do
      hash = GDor::Indexer::SolrDocHash.new({})
      hash.validate_gdor_fields(mock_config).length.should == 5
    end
    it "should have a value for an unrecognized display_type" do
      hash = GDor::Indexer::SolrDocHash.new({
        :access_facet => 'Online',
        :druid => druid,
        :url_fulltext => "#{purl_url}/#{druid}",
        :display_type => 'zzzz', 
        :building_facet => 'Stanford Digital Repository'})
      hash.validate_gdor_fields(mock_config).first.should =~ /display_type/
    end
    it "should have a value for access_facet other than 'Online'" do
      hash = GDor::Indexer::SolrDocHash.new({
        :access_facet => 'BAD',
        :druid => druid,
        :url_fulltext => "#{purl_url}/#{druid}",
        :display_type => 'image', 
        :building_facet => 'Stanford Digital Repository'})
      hash.validate_gdor_fields(mock_config).first.should =~ /access_facet/
    end
    it "should have a value for building_facet other than 'Stanford Digital Repository'" do
      hash = GDor::Indexer::SolrDocHash.new({
        :access_facet => 'Online',
        :druid => druid,
        :url_fulltext => "#{purl_url}/#{druid}",
        :display_type => 'image',
        :building_facet => 'WRONG'})
      hash.validate_gdor_fields(mock_config).first.should =~ /building_facet/
    end
  end # validate_gdor_fields

  context "#validation_mods" do
    let(:mock_config) { {} }
    it 'should have no validation messages for a complete record' do
      hash = GDor::Indexer::SolrDocHash.new({
        :modsxml => 'whatever',
        :title_display => 'title',
        :pub_year_tisim => 'some year',
        :author_person_display => 'author',
        :format_main_ssim => 'Image',
        :format => 'Image',
        :language => 'English'
      })
      hash.validate_mods(mock_config).length.should == 0
    end
    it 'should have validation messages for each missing field' do
      hash = GDor::Indexer::SolrDocHash.new({
        :id => 'whatever',
      })
      hash.validate_mods(mock_config).length.should == 7
    end
  end  

end
