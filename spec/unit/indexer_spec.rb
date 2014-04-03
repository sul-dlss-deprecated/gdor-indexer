require 'spec_helper'
require 'rsolr'
require 'record_merger'

describe Indexer do
  
  before(:all) do
    config_yml_path = File.join(File.dirname(__FILE__), "..", "config", "walters_integration_spec.yml")
    @solr_yml_path = File.join(File.dirname(__FILE__), "..", "config", "solr.yml")
    @indexer = Indexer.new(config_yml_path, @solr_yml_path)
    require 'yaml'
    @yaml = YAML.load_file(config_yml_path)
    @hdor_client = @indexer.send(:harvestdor_client)
    @fake_druid = 'oo000oo0000'
  end
  
  describe "logging" do
    it "should write the log file to the directory indicated by log_dir" do
      @indexer.logger.info("walters_integration_spec logging test message")
      File.exists?(File.join(@yaml['log_dir'], @yaml['log_name'])).should == true
    end
  end

  it "should initialize the harvestdor_client from the config" do
    @hdor_client.should be_an_instance_of(Harvestdor::Client)
    @hdor_client.config.default_set.should == @yaml['default_set']
  end
  
  context "harvest_and_index" do
    before(:each) do
      @indexer.stub(:coll_druid_from_config).and_return(@fake_druid)
      @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML("<mods #{@ns_decl}><note>hi</note></mods>"))
      @hdor_client.stub(:public_xml).with(@fake_druid).and_return(Nokogiri::XML("<publicObject id='druid#{@fake_druid}'></publicObject>"))
      @coll_sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
      @coll_sdb.stub(:coll_object?).and_return(true)
      @indexer.stub(:coll_sdb).and_return(@coll_sdb)
    end
    it "if coll rec from config harvested relationship isn't a coll rec per identity metadata, no further indexing should occur" do
      @coll_sdb.stub(:coll_object?).and_return(false)
      @indexer.stub(:coll_sdb).and_return(@coll_sdb)
      @indexer.logger.should_receive(:fatal).with("#{@fake_druid} is not a collection object!! (per identityMetaadata)  Ending indexing.")
      @indexer.should_not_receive(:index_item)
      @indexer.should_not_receive(:index_collection_druid)
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
    it "should call index_collection_druid once for the coll druid from the config file" do
      Harvestdor::Indexer.any_instance.should_receive(:druids).and_return([])
      @indexer.should_receive(:index_collection_druid)
      @indexer.harvest_and_index(true) # nocommit for ease of testing
    end
  end # harvest_and_index
  
  context "index_item" do
    it "should call solr_add" do
      doc_hash = {
        :id => @fake_druid,
        :field => 'val'
      }
      @indexer.stub(:sw_solr_doc).and_return(doc_hash)
      Harvestdor::Indexer.any_instance.should_receive(:solr_add).with(doc_hash, @fake_druid)
      @indexer.index_item @fake_druid
    end
  end
  
  context "harvest and index collection record" do
    before(:all) do
      @ng_pub_xml = Nokogiri::XML("<publicObject id='druid:#{@fake_druid}'></publicObject>")
      @fake_mods = Nokogiri::XML("<mods #{@ns_decl}><note>coll indexing test</note></mods>")
      @coll_druid_from_test_config = "ww121ss5000"
    end
    it "gets the collection druid from the config" do
      String.any_instance.should_receive(:include?).with('is_member_of_collection_').and_call_original
      @indexer.coll_druid_from_config.should eql(@coll_druid_from_test_config)
    end
    context "unmerged record" do
      it "indexes the collection druid" do
        @indexer.solr_client.should_receive(:add)
        @indexer.index_collection_druid
      end
      context "format" do
        it "should include formats from coll_formats_from_items when the druid matches" do
          @indexer.stub(:coll_formats_from_items).and_return({@coll_druid_from_test_config => ['Image']})
          SolrDocBuilder.any_instance.stub(:doc_hash).and_return({})
          @indexer.solr_client.should_receive(:add).with(hash_including(:format => ['Image']))
          @indexer.index_collection_druid # uses coll_druid_from_test_config
        end
        it "should not include formats from coll_formats_from_items when the druid doesn't match" do
          @indexer.stub(:coll_formats_from_items).and_return({'foo' => ['Image']})
          SolrDocBuilder.any_instance.stub(:doc_hash).and_return({:format => ['Video']})
          @indexer.solr_client.should_receive(:add).with(hash_including(:format => ['Video']))
          @indexer.index_collection_druid # uses coll_druid_from_test_config
        end
        it "should not have duplicate format values" do
          @indexer.stub(:coll_formats_from_items).and_return({@coll_druid_from_test_config => ['Image', 'Video', 'Image']})
          SolrDocBuilder.any_instance.stub(:doc_hash).and_return({:format => ['Video']})
          @indexer.solr_client.should_receive(:add).with(hash_including(:format => ['Image', 'Video']))
          @indexer.index_collection_druid
        end
      end
      it "collection_type should be 'Digital Collection'" do
        @indexer.stub(:sw_solr_doc).and_return({})
        @indexer.solr_client.should_receive(:add).with(hash_including(:collection_type => 'Digital Collection'))
        @indexer.index_collection_druid
      end
    end # unmerged coll record

    context "merged record" do
      before(:each) do
        @ckey = '666'
        @indexer.stub(:coll_catkey).and_return(@ckey)
      end
      it "should call RecordMerger.merge_and_index" do
        RecordMerger.should_receive(:merge_and_index).with('666', hash_including(:url_fulltext, :access_facet => 'Online', 
                                                                                :collection_type => "Digital Collection"))
        @indexer.index_collection_druid
      end
      it "should add a doc to Solr with field collection_type" do
        SolrjWrapper.any_instance.should_receive(:add_doc_to_ix).with(hash_including('collection_type'), @ckey)
        @indexer.index_collection_druid
      end
    end
  end # index collection record
  
  it "druids method should call druids_via_oai method on harvestdor_client" do
    @hdor_client.should_receive(:druids_via_oai).and_return []
    @indexer.druids
  end
  
  context "sw_solr_doc fields" do
    
    before(:all) do
      @ns_decl = "xmlns='#{Mods::MODS_NS}'"
      @mods_xml = "<mods #{@ns_decl}><note>hi</note></mods>"
    end
    before(:each) do
      @title = 'qervavdsaasdfa'
      ng_mods = Nokogiri::XML("<mods #{@ns_decl}><titleInfo><title>#{@title}</title></titleInfo></mods>")
      @hdor_client.stub(:mods).with(@fake_druid).and_return(ng_mods)
      cntnt_md_xml = "<contentMetadata type='image' objectId='#{@fake_druid}'></contentMetadata>"
      ng_pub_xml = Nokogiri::XML("<publicObject id='druid:#{@fake_druid}'>#{cntnt_md_xml}</publicObject>")
      @hdor_client.stub(:public_xml).and_return(ng_pub_xml)
      @doc_hash = @indexer.sw_solr_doc(@fake_druid)
    end

    it "should have fields populated from the MODS" do
      @doc_hash[:title_245_search] = @title
    end
    it "should have fields populated from the public_xml" do
      @doc_hash = @indexer.sw_solr_doc(@fake_druid)
      @doc_hash[:format] = 'Image'
    end
    it "should populate url_fulltext field with purl page url" do
      @doc_hash[:url_fulltext].should == "#{@yaml['purl']}/#{@fake_druid}"
    end
       
    context "coll_druid_2_title_hash" do
      before(:all) do
        @coll_druid = 'ww121ss5000'
        rels_ext_xml = "<rdf:RDF  xmlns:fedora='info:fedora/fedora-system:def/relations-external#' xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'>
        <rdf:Description rdf:about='info:fedora/druid:#{@fake_druid}'>
        <fedora:isMemberOfCollection rdf:resource='info:fedora/druid:#{@coll_druid}'/>
        </rdf:Description></rdf:RDF>"
        @pub_xml = Nokogiri::XML("<publicObject id='druid:#{@fake_druid}'>#{rels_ext_xml}</publicObject>")
        @coll_title = "My Collection Has an Interesting Title"
      end
      before(:each) do
        @hdor_client.stub(:mods).and_return(Nokogiri::XML(@mods_xml))        
        @hdor_client.stub(:public_xml).with(@fake_druid).and_return(@pub_xml)
        @indexer.stub(:identity_md_obj_label).with(@coll_druid).and_return(@coll_title)
      end
      
      it "should add any missing druids" do
        @indexer.coll_druid_2_title_hash.keys.should == []
        @indexer.sw_solr_doc(@fake_druid)
        @indexer.coll_druid_2_title_hash.keys.should == [@coll_druid]
      end
      it "should retrieve missing collection titles via identity_md_obj_label" do
        @indexer.sw_solr_doc(@fake_druid)
        @indexer.coll_druid_2_title_hash[@coll_druid].should == @coll_title
      end
      it "should be used to add collection field to solr doc" do
        doc_hash = @indexer.sw_solr_doc(@fake_druid)
        doc_hash[:collection].should == [@coll_druid]
      end
      it "should add two collection field values when object belongs to two collections" do
        item_druid = 'oo123oo4567'
        coll_druid1 = 'oo111oo2222'
        coll_druid2 = 'oo333oo4444'
        rels_ext_xml = "<rdf:RDF  xmlns:fedora='info:fedora/fedora-system:def/relations-external#' xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'>
        <rdf:Description rdf:about='info:fedora/druid:#{item_druid}'>
        <fedora:isMemberOfCollection rdf:resource='info:fedora/druid:#{coll_druid1}'/>
        <fedora:isMemberOfCollection rdf:resource='info:fedora/druid:#{coll_druid2}'/>
        </rdf:Description></rdf:RDF>"
        pub_xml = Nokogiri::XML("<publicObject id='druid:#{item_druid}'>#{rels_ext_xml}</publicObject>")
        @hdor_client.stub(:public_xml).with(item_druid).and_return(pub_xml)
        @hdor_client.stub(:mods).with(item_druid).and_return(Nokogiri::XML(@mods_xml))
        @indexer.stub(:identity_md_obj_label).with(coll_druid1).and_return('foo')
        @indexer.stub(:identity_md_obj_label).with(coll_druid2).and_return('bar')
        doc_hash = @indexer.sw_solr_doc(item_druid)
        doc_hash[:collection].should == [coll_druid1, coll_druid2]
        doc_hash[:collection_with_title].should == ["#{coll_druid1}-|-foo", "#{coll_druid2}-|-bar"]
      end
      it "should add no collection field values if there are none" do
        item_druid = 'oo123oo4567'
        rels_ext_xml = "<rdf:RDF  xmlns:fedora='info:fedora/fedora-system:def/relations-external#' xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'>
        <rdf:Description rdf:about='info:fedora/druid:#{item_druid}'>
        </rdf:Description></rdf:RDF>"
        pub_xml = Nokogiri::XML("<publicObject id='druid:#{item_druid}'>#{rels_ext_xml}</publicObject>")
        @hdor_client.stub(:public_xml).with(item_druid).and_return(pub_xml)
        @hdor_client.stub(:mods).with(item_druid).and_return(Nokogiri::XML(@mods_xml))
        doc_hash = @indexer.sw_solr_doc(item_druid)
        doc_hash[:collection].should == nil
        doc_hash[:collection_with_title].should == nil
      end
      it "should be used to add collection_with_title field to solr doc" do
        doc_hash = @indexer.sw_solr_doc(@fake_druid)
        doc_hash[:collection_with_title].should == ["#{@coll_druid}-|-#{@coll_title}"]
      end
    end # coll_druid_2_title_hash

    context "#coll_formats_from_items" do
      before(:all) do
        @coll_druid_from_config = 'ww121ss5000'
      end
      before(:each) do
        @indexer.coll_formats_from_items[@coll_druid_from_config] = []
      end
      it "gets single item format for single collection" do
        # setup
        m = "<mods #{@ns_decl}>
          <typeOfResource>still image</typeOfResource>
        </mods>"
        @hdor_client.stub(:mods).and_return(Nokogiri::XML(m))
        SolrDocBuilder.any_instance.stub(:coll_druids_from_rels_ext).and_return([@coll_druid_from_config])
        @indexer.stub(:identity_md_obj_label).with(@coll_druid_from_config).and_return('coll title')
        # actual test
        @indexer.sw_solr_doc 'fake_item_druid'
        @indexer.coll_formats_from_items[@coll_druid_from_config].should == ['Image']
      end
      it "gets multiple formats from single item for single collection" do
        # setup
        @hdor_client.stub(:mods).and_return(Nokogiri::XML("<mods #{@ns_decl}> </mods>"))
        SolrDocBuilder.any_instance.stub(:coll_druids_from_rels_ext).and_return([@coll_druid_from_config])
        @indexer.stub(:identity_md_obj_label).with(@coll_druid_from_config).and_return('coll title')
        Stanford::Mods::Record.any_instance.stub(:format).and_return(['Image', 'Video'])
        # actual test
        @indexer.sw_solr_doc 'fake_item_druid'
        @indexer.coll_formats_from_items[@coll_druid_from_config].should == ['Image', 'Video']
      end
      it "gets multiple formats from multiple items for single collection" do
        # setup
        @hdor_client.stub(:mods).and_return(Nokogiri::XML("<mods #{@ns_decl}> </mods>"))
        SolrDocBuilder.any_instance.stub(:coll_druids_from_rels_ext).and_return([@coll_druid_from_config])
        @indexer.stub(:identity_md_obj_label).with(@coll_druid_from_config).and_return('coll title')
        Stanford::Mods::Record.any_instance.stub(:format).and_return(['Image'])
        # actual test
        @indexer.sw_solr_doc 'fake_item_druid'
        Stanford::Mods::Record.any_instance.stub(:format).and_return(['Video'])
        # actual test
        @indexer.sw_solr_doc 'fake_item_druid2'
        @indexer.coll_formats_from_items[@coll_druid_from_config].should == ['Image', 'Video']
      end
    end # coll_formats_from_items
  end # sw_solr_doc
  
  it "solr_client should initialize the rsolr client using the options from the config" do
    indexer = Indexer.new(nil, @solr_yml_path, Confstruct::Configuration.new(:solr => { :url => 'http://localhost:2345', :a => 1 }) )
    RSolr.should_receive(:connect).with(hash_including(:url => 'http://solr.baseurl.org'))
    indexer.solr_client
  end
  
  context "identity_md_obj_label" do
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
  
  context "count_recs_in_solr" do
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

end