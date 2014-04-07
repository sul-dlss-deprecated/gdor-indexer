require 'spec_helper'
require 'rsolr'
require 'record_merger'

describe Indexer do
  
  before(:all) do
    @config_yml_path = File.join(File.dirname(__FILE__), "..", "config", "walters_integration_spec.yml")
    @solr_yml_path = File.join(File.dirname(__FILE__), "..", "config", "solr.yml")
    require 'yaml'
    @yaml = YAML.load_file(@config_yml_path)
    @ns_decl = "xmlns='#{Mods::MODS_NS}'"
    @fake_druid = 'oo000oo0000'
    @coll_druid_from_test_config = "ww121ss5000"
    @ng_mods_xml =  Nokogiri::XML("<mods #{@ns_decl}><note>Indexer test</note></mods>")
    @ng_pub_xml = Nokogiri::XML("<publicObject id='druid#{@fake_druid}'></publicObject>")
  end
  before(:each) do
    @indexer = Indexer.new(@config_yml_path, @solr_yml_path)
    @hdor_client = @indexer.send(:harvestdor_client)
    @hdor_client.stub(:public_xml).and_return(@ng_pub_xml)
  end
  
  context "logging" do
    it "should write the log file to the directory indicated by log_dir" do
      @indexer.logger.info("walters_integration_spec logging test message")
      File.exists?(File.join(@yaml['log_dir'], @yaml['log_name'])).should == true
    end
  end

  it "should initialize the harvestdor_client from the config" do
    @hdor_client.should be_an_instance_of(Harvestdor::Client)
    @hdor_client.config.default_set.should == @yaml['default_set']
  end
  
  context "#harvest_and_index" do
    before(:each) do
      @indexer.stub(:coll_druid_from_config).and_return(@fake_druid)
      @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      @hdor_client.stub(:public_xml).with(@fake_druid).and_return(@ng_pub_xml)
      @coll_sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
      @coll_sdb.stub(:coll_object?).and_return(true)
      @indexer.stub(:coll_sdb).and_return(@coll_sdb)
    end
    it "if coll rec from config harvested relationship isn't a coll rec per identity metadata, no further indexing should occur" do
      @coll_sdb.stub(:coll_object?).and_return(false)
      @indexer.stub(:coll_sdb).and_return(@coll_sdb)
      @indexer.logger.should_receive(:fatal).with("#{@fake_druid} is not a collection object!! (per identityMetaadata)  Ending indexing.")
      @indexer.should_not_receive(:index_item)
      @indexer.should_not_receive(:index_coll_obj_per_config)
      @indexer.solr_client.should_not_receive(:commit)
      @indexer.harvest_and_index
    end
    it "should call index_item for each druid" do
      Harvestdor::Indexer.any_instance.should_receive(:druids).and_return(['1', '2', '3'])
      @indexer.should_receive(:index_item).with('1')
      @indexer.should_receive(:index_item).with('2')
      @indexer.should_receive(:index_item).with('3')
      @indexer.harvest_and_index(true) # nocommit for ease of testing
    end
    it "should call index_coll_obj_per_config once for the coll druid from the config file" do
      Harvestdor::Indexer.any_instance.should_receive(:druids).and_return([])
      @indexer.should_receive(:index_coll_obj_per_config)
      @indexer.harvest_and_index(true) # nocommit for ease of testing
    end
  end # harvest_and_index
  
  context "#index_item" do
    context "merge or not?" do
      it "uses RecordMerger if there is a catkey" do
        pending "need to implement item level merge"
        ckey = '666'
        SolrDocBuilder.any_instance.stub(:catkey).and_return(ckey)
        RecordMerger.should_receive(:merge_and_index)
        @indexer.index_item @fake_druid
      end
      it "does not use RecordMerger if there isn't a catkey" do
        RecordMerger.should_not_receive(:merge_and_index)
        sdb = double
        sdb.stub(:catkey).and_return(nil)
        sdb.stub(:public_xml)
        sdb.stub(:doc_hash).and_return({}) # speed up the test
        sdb.stub(:coll_druids_from_rels_ext)
        sdb.stub(:validate_mods).and_return([])
        SolrDocBuilder.stub(:new).and_return(sdb)
        @indexer.solr_client.should_receive(:add)
        @indexer.index_item @fake_druid
      end
    end

    context "unmerged" do
      before(:each) do
        @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      end
      it "should call solr_add" do
        Harvestdor::Indexer.any_instance.should_receive(:solr_add).with(instance_of(Hash), @fake_druid)
        @indexer.index_item @fake_druid
      end
      it "validates the item doc via validate_item" do
        @indexer.should_receive(:validate_item)
        @indexer.index_item @fake_druid
      end
      it "validates the item doc via SolrDocBuilder.validate_mods" do
        SolrDocBuilder.any_instance.should_receive(:validate_mods)
        @indexer.index_item @fake_druid
      end
      it "should have fields populated from the MODS" do
        title = 'fake title in mods'
        ng_mods = Nokogiri::XML("<mods #{@ns_decl}><titleInfo><title>#{title}</title></titleInfo></mods>")
        @hdor_client.stub(:mods).with(@fake_druid).and_return(ng_mods)
        Harvestdor::Indexer.any_instance.should_receive(:solr_add).with(hash_including(:title_245_search => title), @fake_druid)
        @indexer.index_item @fake_druid
      end
      it "should have fields populated from the public_xml" do
        cntnt_md_xml = "<contentMetadata type='image' objectId='#{@fake_druid}'></contentMetadata>"
        ng_pub_xml = Nokogiri::XML("<publicObject id='druid:#{@fake_druid}'>#{cntnt_md_xml}</publicObject>")
        @hdor_client.stub(:public_xml).and_return(ng_pub_xml)
        Harvestdor::Indexer.any_instance.should_receive(:solr_add).with(hash_including(:display_type => 'image'), @fake_druid)
        @indexer.index_item @fake_druid
      end
      it "should populate url_fulltext field with purl page url" do
        Harvestdor::Indexer.any_instance.should_receive(:solr_add).with(hash_including(:url_fulltext => "#{@yaml['purl']}/#{@fake_druid}"), @fake_druid)
        @indexer.index_item @fake_druid
      end
      it "validates the item doc via validate_item" do
        @indexer.should_receive(:validate_item)
        @indexer.index_item @fake_druid
      end
      it "validates the item doc via SolrDocBuilder.validate_mods" do
        SolrDocBuilder.any_instance.should_receive(:validate_mods)
        @indexer.index_item @fake_druid
      end
    end # umerged item

    context "merged with marc" do
      it "does something" do
        pending "item level merge to be implemented"
      end
    end # merged item
  end # index_item 
  
  it "coll_druid_from_config gets the druid from the config" do
    String.any_instance.should_receive(:include?).with('is_member_of_collection_').and_call_original
    @indexer.coll_druid_from_config.should eql(@coll_druid_from_test_config)
  end

  context "#index_coll_obj_per_config" do
    context "merge or not?" do
      it "uses RecordMerger if there is a catkey" do
        ckey = '666'
        @indexer.stub(:coll_catkey).and_return(ckey)
        RecordMerger.should_receive(:merge_and_index)
        @indexer.index_coll_obj_per_config
      end
      it "does not use RecordMerger if there isn't a catkey" do
        @indexer.stub(:coll_catkey).and_return(nil)
        RecordMerger.should_not_receive(:merge_and_index)
        SolrDocBuilder.any_instance.stub(:doc_hash).and_return({}) # speed up the test
        @indexer.solr_client.should_receive(:add)
        @indexer.index_coll_obj_per_config
      end
    end
    
    context "unmerged" do
      it "adds the collection doc to the index" do
        SolrDocBuilder.any_instance.stub(:doc_hash).and_return({}) # speed up the test
        @indexer.solr_client.should_receive(:add)
        @indexer.index_coll_obj_per_config
      end
      it "validates the collection doc via validate_collection" do
        SolrDocBuilder.any_instance.stub(:doc_hash).and_return({}) # speed up the test
        @indexer.should_receive(:validate_collection)
        @indexer.index_coll_obj_per_config
      end
      it "validates the collection doc via SolrDocBuilder.validate_mods" do
        SolrDocBuilder.any_instance.stub(:doc_hash).and_return({}) # speed up the test
        SolrDocBuilder.any_instance.should_receive(:validate_mods)
        @indexer.index_coll_obj_per_config
      end
      context "format" do
        it "should include formats from coll_formats_from_items when the druid matches" do
          @indexer.stub(:coll_formats_from_items).and_return({@coll_druid_from_test_config => ['Image']})
          SolrDocBuilder.any_instance.stub(:doc_hash).and_return({})
          @indexer.solr_client.should_receive(:add).with(hash_including(:format => ['Image']))
          @indexer.index_coll_obj_per_config
        end
        it "should not include formats from coll_formats_from_items when the druid doesn't match" do
          @indexer.stub(:coll_formats_from_items).and_return({'foo' => ['Image']})
          SolrDocBuilder.any_instance.stub(:doc_hash).and_return({:format => ['Video']})
          @indexer.solr_client.should_receive(:add).with(hash_including(:format => ['Video']))
          @indexer.index_coll_obj_per_config
        end
        it "should not have duplicate format values" do
          @indexer.stub(:coll_formats_from_items).and_return({@coll_druid_from_test_config => ['Image', 'Video', 'Image']})
          SolrDocBuilder.any_instance.stub(:doc_hash).and_return({:format => ['Video']})
          @indexer.solr_client.should_receive(:add).with(hash_including(:format => ['Image', 'Video']))
          @indexer.index_coll_obj_per_config
        end
      end
      it "collection_type should be 'Digital Collection'" do
        SolrDocBuilder.any_instance.stub(:doc_hash).and_return({}) # speed up the test
        @indexer.solr_client.should_receive(:add).with(hash_including(:collection_type => 'Digital Collection'))
        @indexer.index_coll_obj_per_config
      end
    end # unmerged 

    context "merged with marc" do
      before(:each) do
        @ckey = '666'
        @indexer.stub(:coll_catkey).and_return(@ckey)
      end
      it "should call RecordMerger.merge_and_index" do
        RecordMerger.should_receive(:merge_and_index).with(@ckey, hash_including(:url_fulltext, :access_facet => 'Online', 
                                                                                :collection_type => "Digital Collection"))
        @indexer.index_coll_obj_per_config
      end
      it "validates the collection doc via validate_collection" do
        SolrDocBuilder.any_instance.stub(:doc_hash).and_return({}) # speed up the test
        @indexer.should_receive(:validate_collection)
        @indexer.index_coll_obj_per_config
      end
      it "should add a doc to Solr with field collection_type" do
        SolrjWrapper.any_instance.should_receive(:add_doc_to_ix).with(hash_including('collection_type'), @ckey)
        @indexer.index_coll_obj_per_config
      end
    end
  end #  index_coll_obj_per_config
  
  it "druids method should call druids_via_oai method on harvestdor_client" do
    @hdor_client.should_receive(:druids_via_oai).and_return []
    @indexer.druids
  end
  
  context "#add_coll_info" do
    before(:all) do
      @coll_druids_array = [@coll_druid_from_test_config]
    end

    it "should add no collection field values to doc_hash if there are none" do
      doc_hash = {}
      @indexer.add_coll_info(doc_hash, nil)
      doc_hash[:collection].should == nil
      doc_hash[:collection_with_title].should == nil
    end
    
    context "collection field" do
      it "should be added field to doc hash" do
        doc_hash = {}
        @indexer.add_coll_info(doc_hash, @coll_druids_array)
        doc_hash[:collection].should == [@coll_druid_from_test_config]
      end
      it "should add two values to doc_hash when object belongs to two collections" do
        coll_druid1 = 'oo111oo2222'
        coll_druid2 = 'oo333oo4444'
        @indexer.stub(:identity_md_obj_label)
        doc_hash = {}
        @indexer.add_coll_info(doc_hash, [coll_druid1, coll_druid2])
        doc_hash[:collection].should == [coll_druid1, coll_druid2]
      end
    end

    context "collection_with_title field" do
      it "should be added to doc_hash" do
        coll_druid = 'oo000oo1234'
        @indexer.should_receive(:identity_md_obj_label).with(coll_druid).and_return('zzz')
        doc_hash = {}
        @indexer.add_coll_info(doc_hash, [coll_druid])
        doc_hash[:collection_with_title].should == ["#{coll_druid}-|-zzz"]
      end
      it "should add two values to doc_hash when object belongs to two collections" do
        coll_druid1 = 'oo111oo2222'
        coll_druid2 = 'oo333oo4444'
        @indexer.should_receive(:identity_md_obj_label).with(coll_druid1).and_return('foo')
        @indexer.should_receive(:identity_md_obj_label).with(coll_druid2).and_return('bar')
        doc_hash = {}
        @indexer.add_coll_info(doc_hash, [coll_druid1, coll_druid2])
        doc_hash[:collection_with_title].should == ["#{coll_druid1}-|-foo", "#{coll_druid2}-|-bar"]
      end
    end
    
    context "coll_druid_2_title_hash interactions" do
      it "should add any missing druids" do
        @indexer.stub(:coll_druid_2_title_hash).and_return({})
        @indexer.stub(:identity_md_obj_label)
        @indexer.add_coll_info({}, @coll_druids_array)
        @indexer.coll_druid_2_title_hash.keys.should == @coll_druids_array
      end
      it "should retrieve missing collection titles via identity_md_obj_label" do
        @indexer.stub(:identity_md_obj_label).and_return('qqq')
        @indexer.add_coll_info({}, @coll_druids_array)
        @indexer.coll_druid_2_title_hash[@coll_druid_from_test_config].should == 'qqq'
      end
    end # coll_druid_2_title_hash

    context "#coll_formats_from_items" do
      before(:each) do
        @hdor_client.stub(:public_xml).and_return(@ng_pub_xml)
        @indexer.coll_formats_from_items[@coll_druid_from_test_config] = []
      end
      it "gets single item format for single collection" do
        @indexer.stub(:identity_md_obj_label)
        doc_hash = {:format => 'Image'}
        @indexer.add_coll_info(doc_hash, @coll_druids_array)
        @indexer.coll_formats_from_items[@coll_druid_from_test_config].should == ['Image']
      end
      it "gets multiple formats from single item for single collection" do
        @indexer.stub(:identity_md_obj_label)
        doc_hash = {:format => ['Image', 'Video']}
        @indexer.add_coll_info(doc_hash, @coll_druids_array)
        @indexer.coll_formats_from_items[@coll_druid_from_test_config].should == ['Image', 'Video']
      end
      it "gets multiple formats from multiple items for single collection" do
        @indexer.stub(:identity_md_obj_label)
        doc_hash = {:format => 'Image'}
        @indexer.add_coll_info(doc_hash, @coll_druids_array)
        doc_hash = {:format => 'Video'}
        @indexer.add_coll_info(doc_hash, @coll_druids_array)
        @indexer.coll_formats_from_items[@coll_druid_from_test_config].should == ['Image', 'Video']
      end
    end # coll_formats_from_items
  end #add_coll_info
    
  it "solr_client should initialize the rsolr client using the options from the config" do
    indexer = Indexer.new(nil, @solr_yml_path, Confstruct::Configuration.new(:solr => { :url => 'http://localhost:2345', :a => 1 }) )
    RSolr.should_receive(:connect).with(hash_including(:url => 'http://solr.baseurl.org'))
    indexer.solr_client
  end
  
  context "#identity_md_obj_label" do
    before(:all) do
      @coll_title = "My Collection Has a Lovely Title"
      @ng_id_md_xml = Nokogiri::XML("<identityMetadata><objectLabel>#{@coll_title}</objectLabel></identityMetadata>")
    end
    before(:each) do
      @hdor_client.stub(:identity_metadata).with(@fake_druid).and_return(@ng_id_md_xml)
    end
    it "should retrieve the identityMetadata via the harvestdor client" do
      @hdor_client.should_receive(:identity_metadata).with(@fake_druid)
      @indexer.identity_md_obj_label(@fake_druid)
    end
    it "should get the value of the objectLabel element in the identityMetadata" do
      @indexer.identity_md_obj_label(@fake_druid).should == @coll_title
    end
  end
  
  context "#count_recs_in_solr" do
    before :each do 
      @collection_response = {'response' => {'numFound'=>'1','docs'=>[{'id'=>'dm212rn7381', 'url_fulltext' => ['http://purl.stanford.edu/dm212rn7381']}]}}
      @bad_collection_response = {'response' => {'numFound'=>'1','docs'=>[{'id'=>'dm212rn7381'}]}}
      @item_response = {'response' => {'numFound'=>'265','docs'=>[{'id'=>'dm212rn7381'}]}}
    end

    it 'should count the items and the collection object in the solr index after indexing' do
      @indexer.solr_client.stub(:get) do |wt, params|
        if params[:params][:fl].include?('url_full')
          @collection_response
        else
          @item_response
        end
      end
      @indexer.count_recs_in_solr.should == 266
    end
    it 'should verify the collection object has a purl' do
      @indexer.solr_client.stub(:get) do |wt, params|
        if params[:qt]
          @bad_collection_response
        else
          @item_response
        end
        @indexer.count_recs_in_solr.should == 265
      end
    end
  end # count_recs_in_solr

  context "#validate_gdor_fields" do
    it "should return an empty Array when there are no problems" do
      hash = {
        :access_facet => 'Online',
        :druid => @fake_druid,
        :url_fulltext => "#{@yaml['purl']}/#{@fake_druid}",
        :display_type => 'image'}
      @indexer.validate_gdor_fields(@fake_druid, hash).should == []
    end
    it "should have a value for each missing field" do
      @indexer.validate_gdor_fields(@fake_druid, {}).length.should == 4
    end
    it "should have a value for an unrecognized display_type" do
      hash = {
        :access_facet => 'Online',
        :druid => @fake_druid,
        :url_fulltext => "#{@yaml['purl']}/#{@fake_druid}",
        :display_type => 'zzzz'}
      @indexer.validate_gdor_fields(@fake_druid, hash).first.should =~ /display_type/
    end
    it "should have a value for access_facet other than 'Online'" do
      hash = {
        :access_facet => 'BAD',
        :druid => @fake_druid,
        :url_fulltext => "#{@yaml['purl']}/#{@fake_druid}",
        :display_type => 'image'}
        @indexer.validate_gdor_fields(@fake_druid, hash).first.should =~ /access_facet/
    end
  end # validate_gdor_fields

  context "#validate_item" do
    before(:each) do
      @indexer.stub(:validate_gdor_fields).and_return([])
    end
    it "should call validate_gdor_fields" do
      @indexer.should_receive(:validate_gdor_fields)
      @indexer.validate_item(@fake_druid, {})
    end
    it "should have a value if collection is wrong" do
      hash = {
        :collection => 'junk',
        :collection_with_title => "#{@coll_druid_from_test_config}-|-asdasdf",
        :file_id => 'anything'
      }
      @indexer.validate_item(@fake_druid, hash).first.should =~ /collection /
    end
    it "should have a value if collection_with_title is missing" do
      hash = {
        :collection => @coll_druid_from_test_config,
        :collection_with_title => nil,
        :file_id => 'anything'
      }
      @indexer.validate_item(@fake_druid, hash).first.should =~ /collection_with_title /
    end
    it "should have a value if collection_with_title is missing the title" do
      hash = {
        :collection => @coll_druid_from_test_config,
        :collection_with_title => "#{@coll_druid_from_test_config}-|-",
        :file_id => 'anything'
      }
      @indexer.validate_item(@fake_druid, hash).first.should =~ /collection_with_title /
    end
    it "should have a value if file_id field is missing" do
      hash = {
        :collection => @coll_druid_from_test_config,
        :collection_with_title => "#{@coll_druid_from_test_config}-|-asdasdf",
        :file_id => nil
      }
      @indexer.validate_item(@fake_druid, hash).first.should =~ /file_id/
    end
    it "should not have a value if gdor_fields and item fields are ok" do
      hash = {
        :collection => @coll_druid_from_test_config,
        :collection_with_title => "#{@coll_druid_from_test_config}-|-asdasdf",
        :file_id => 'anything'
      }
      @indexer.validate_item(@fake_druid, hash).should == []
    end
  end # validate_item

  context "#validate_collection" do
    before(:each) do
      @indexer.stub(:validate_gdor_fields).and_return([])
    end
    it "should call validate_gdor_fields" do
      @indexer.should_receive(:validate_gdor_fields)
      @indexer.validate_collection(@fake_druid, {})
    end
    it "should have a value if collection_type is missing" do
      @indexer.validate_collection(@fake_druid, {}).first.should =~ /collection_type/
    end
    it "should have a value if collection_type is not 'Digital Collection'" do
      @indexer.validate_collection(@fake_druid, {:collection_type => 'lalalalala'}).first.should =~ /collection_type/
    end
    it "should not have a value if gdor_fields and collection_type are ok" do
      @indexer.validate_collection(@fake_druid, {:collection_type => 'Digital Collection'}).should == []
    end
  end # validate_collection

end
