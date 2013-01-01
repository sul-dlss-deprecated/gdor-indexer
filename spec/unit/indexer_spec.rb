require 'spec_helper'
require 'rsolr'

describe Indexer do
  
  before(:all) do
    config_yml_path = File.join(File.dirname(__FILE__), "..", "config", "walters_integration_spec.yml")
    @indexer = Indexer.new(config_yml_path)
    require 'yaml'
    @yaml = YAML.load_file(config_yml_path)
    @hclient = @indexer.send(:harvestdor_client)
    @fake_druid = 'oo000oo0000'
  end
  
  describe "logging" do
    it "should write the log file to the directory indicated by log_dir" do
      @indexer.logger.info("walters_integration_spec logging test message")
      File.exists?(File.join(@yaml['log_dir'], @yaml['log_name'])).should == true
    end
  end

  it "should initialize the harvestdor_client from the config" do
    @hclient.should be_an_instance_of(Harvestdor::Client)
    @hclient.config.default_set.should == @yaml['default_set']
  end
  
  it "druids method should call druids_via_oai method on harvestdor_client" do
    @hclient.should_receive(:druids_via_oai)
    @indexer.druids
  end
  
  context "solr_client" do
    it "should initialize the rsolr client using the options from the config" do
      @indexer.stub(:config).and_return { Confstruct::Configuration.new :solr => { :url => 'http://localhost:2345', :a => 1 } }
      RSolr.should_receive(:connect).with(hash_including(:a => 1, :url => 'http://localhost:2345'))
      @indexer.solr_client
    end
  end
  
  context "identity_md_obj_label" do
    before(:all) do
      @coll_title = "My Collection Has a Lovely Title"
      @ng_id_md_xml = Nokogiri::XML("<identityMetadata><objectLabel>#{@coll_title}</objectLabel></identityMetadata>")
    end
    before(:each) do
      @hclient.stub(:identity_metadata).with(@fake_druid).and_return(@ng_id_md_xml)
    end
    it "should retrieve the identityMetadata via the harvestdor client" do
      @hclient.should_receive(:identity_metadata).with(@fake_druid)
      @indexer.identity_md_obj_label(@fake_druid)
    end
    it "should get the value of the objectLabel element in the identityMetadata" do
      @indexer.identity_md_obj_label(@fake_druid).should == @coll_title
    end
  end
  
  context "sw_solr_doc fields" do
    context "coll_hash (which maps coll druids to coll titles without extra calls to purl server)" do
      before(:all) do
        @ns_decl = "xmlns='#{Mods::MODS_NS}'"
        @coll_druid = 'ww121ss5000'
        rels_ext_xml = "<rdf:RDF  xmlns:fedora='info:fedora/fedora-system:def/relations-external#' xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'>
          <rdf:Description rdf:about='info:fedora/druid:#{@fake_druid}'>
            <fedora:isMemberOfCollection rdf:resource='info:fedora/druid:#{@coll_druid}'/>
          </rdf:Description></rdf:RDF>"
        @pub_xml = Nokogiri::XML("<publicObject id='druid:#{@fake_druid}'>#{rels_ext_xml}</publicObject>")
        @coll_title = "My Collection Has an Interesting Title"
      end
      before(:each) do
        @hclient.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML("<mods #{@ns_decl}><note>hi</note></mods>"))
        @hclient.stub(:public_xml).with(@fake_druid).and_return(@pub_xml)
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
        @hclient.stub(:public_xml).with(item_druid).and_return(pub_xml)
        @hclient.stub(:mods).with(item_druid).and_return(Nokogiri::XML("<mods #{@ns_decl}><note>hi</note></mods>"))
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
        @hclient.stub(:public_xml).with(item_druid).and_return(pub_xml)
        @hclient.stub(:mods).with(item_druid).and_return(Nokogiri::XML("<mods #{@ns_decl}><note>hi</note></mods>"))
        doc_hash = @indexer.sw_solr_doc(item_druid)
        doc_hash[:collection].should == nil
        doc_hash[:collection_with_title].should == nil
      end
      it "should be used to add collection_with_title field to solr doc" do
        doc_hash = @indexer.sw_solr_doc(@fake_druid)
        doc_hash[:collection_with_title].should == ["#{@coll_druid}-|-#{@coll_title}"]
      end
    end
   
# FIXME: these should all be tests that solrdocbuilder methods are called
    
    # see https://consul.stanford.edu/display/NGDE/Required+and+Recommended+Solr+Fields+for+SearchWorks+documents
    context "DOR specific" do
      before(:all) do
        smr = Stanford::Mods::Record.new
        smr.from_str '<mods><note>hi</note></mods>'
  #      @doc_hash = @indexer.sw_solr_doc(@fake_druid)
      end

      it "should have a druid field" do
        pending
        @doc_hash[:druid].should == @fake_druid
      end
      it "should have a url_fulltext field to the purl landing page" do
        pending
        @doc_hash[:url_fulltext].should == "#{@yaml['purl']}/#{@fake_druid}"
      end
      it "should have the full MODS in the modsxml field" do
        pending "now elsewhere?"
        @indexer.send(:harvestdor_client).stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        doc_hash = @indexer.sw_solr_doc(@fake_druid)
        doc_hash[:modsxml].should be_equivalent_to m
      end
      context "collection fields for item objects" do
        # FIXME:  update per gryphDOR code / searcworks code / new schema
        it "should populate collection with the id of the parent coll" do
          pending "to be implemented, using controlled vocab, in harvestdor"
        end
        it "should not have a collection_search field, as it is a copy field for collection" do
          pending
          @doc_hash[:collection_search].should == nil
        end
        # <!--  easy way to indicate collection's parent in UI (may be deprecated in future) -->
        # <field name="collection_with_title" type="string" indexed="false" stored="true" multiValued="true"/>
        it "should have parent_coll_ckey if it is a item object?" do
          pending "to be implemented"
        end        
        it "should have collection_type" do
          pending "to be implemented"
          # <!--  used to determine when something is a digital collection -->
          # <field name="collection_type" type="string" indexed="true" stored="true" multiValued="true"/>
        end
      end
      it "should have img_info if there are images associated with the object" do
        pending "to be implemented"
        # <field name="img_info" type="string" indexed="false" stored="true" multiValued="true"/>
      end
    end
    context "SearchWorks required fields" do
      it "should have a single id value of druid" do
        pending
        @doc_hash[:id].should == @fake_druid
      end
      it "should have display_type field" do
        # <!-- display_type is a hidden facet for "views" e.g. Images, Maps ...  (might be obsolete) -->
        # <field name="display_type" type="string" indexed="true" stored="false" multiValued="true" omitNorms="true"/>
        pending "to be implemented"
      end
      it "all_search - not a copy field?" do
        pending "to be implemented"
      end

      it "should have a format" do
        pending "to be implemented, using SearchWorks controlled vocab"
      end
    end
    context "SearchWorks strongly recommended fields" do
      it "should have an access_facet value of 'Online'" do
        pending
        @doc_hash[:access_facet].should == 'Online'
      end
      it "should have title fields" do
        pending "to be implemented"
        # short title, full title, alternate title, sorting title ...

#        display (will revert to id if no display title is available)
#            title_display  
#            title_245a_display
#            title_full_display
#        searching (huge impact on generic search results)
#            title_245a_search
#            title_245_search
#        title_sort (if missing, the document will sort last)
      end
    end
    context "SearchWorks recommended fields" do
      it "should have publication date fields" do
        pending "to be implemented"
#        pub_date
#        pub_date_sort
#        pub_date_group_facet
#            we may need a gem or service to compute this - the code from pub_date to pub_date_group is in solrmarc-sw
      end
      it "language" do
        pending "to be implemented"
#        language of the work
#        controlled vocab (though a large one): http://searchworks-solr-lb.stanford.edu:8983/solr/select?facet.field=language&rows=0&facet.limit=1000
      end
    end
    context "MODS/GryphonDOR specific fields" do
      # <field name="access_condition_display" type="string" indexed="false" stored="true" multiValued="true"/>
      # <field name="era_display" type="string" indexed="false" stored="true" multiValued="true"/>
      # <field name="geographic_display" type="string" indexed="false" stored="true" multiValued="true"/>
      # <field name="issue_date_display" type="string" indexed="false" stored="true" multiValued="true"/>
      # <field name="physical_location_display" type="string" indexed="false" stored="true" multiValued="true"/>
      
    end
  end
  
  it "should write a Solr doc to the solr index" do
    pending "to be implemented"
    # doc with:  druid, access_facet, url_fulltext
  end

end