require 'spec_helper'
require 'rsolr'

describe Indexer do
  
  before(:all) do
    config_yml_path = File.join(File.dirname(__FILE__), "..", "config", "walters_integration_spec.yml")
    @indexer = Indexer.new(config_yml_path)
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
  
  context "harvest_and_index item records" do
    it "should call druids and then call :add on rsolr connection" do
      pending 
      doc_hash = {
        :id => @fake_druid,
        :field => 'val'
      }
      @indexer.stub(:sw_solr_doc).and_return(doc_hash)
      @hdor_client.should_receive(:druids_via_oai).and_return([@fake_druid])
      @indexer.solr_client.should_receive(:add).with(doc_hash)
      @indexer.solr_client.stub(:commit)
      @indexer.harvest_and_index
    end
  end
  
  context "harvest and index collection record" do
    it "gets the collection druid" do
      @indexer.collection_druid.should eql("ww121ss5000")
    end
    it "indexes the collection druid" do
      @indexer.solr_client.should_receive(:add)
      @indexer.index_collection_druid
    end
  end
  
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
       
    context "coll_hash (which maps coll druids to coll titles without extra calls to purl server)" do
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
        @indexer.coll_hash.keys.should == []
        @indexer.sw_solr_doc(@fake_druid)
        @indexer.coll_hash.keys.should == [@coll_druid]
      end
      it "should retrieve missing collection titles via identity_md_obj_label" do
        @indexer.sw_solr_doc(@fake_druid)
        @indexer.coll_hash[@coll_druid].should == @coll_title
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
    end # coll_hash

  end # sw_solr_doc
  
  it "solr_client should initialize the rsolr client using the options from the config" do
    indexer = Indexer.new(nil, Confstruct::Configuration.new(:solr => { :url => 'http://localhost:2345', :a => 1 }) )
    RSolr.should_receive(:connect).with(hash_including(:a => 1, :url => 'http://localhost:2345')).and_return('foo')
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
  
end