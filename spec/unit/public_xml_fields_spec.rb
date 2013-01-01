require 'spec_helper'
# FIXME:  should all these be required, chain-wise, in Indexer class?
require 'public_xml_fields'

describe 'SearchworksFields mixin for SolrDocBuilder class' do

  before(:all) do
    @fake_druid = 'oo000oo0000'
    @ns_decl = "xmlns='#{Mods::MODS_NS}'"
    @ng_mods_xml = Nokogiri::XML("<mods #{@ns_decl}><note>hi</note></mods>")
  end
    
  # NOTE:  
  # "Doubles, stubs, and message expectations are all cleaned out after each example."
  # per https://www.relishapp.com/rspec/rspec-mocks/docs/scope
  
  context "fields from and methods pertaining to contentMetadata" do
    before(:all) do
      @cntnt_md_type = 'image'
      @cntnt_md_xml = "<contentMetadata type='#{@cntnt_md_type}' objectId='#{@fake_druid}'></contentMetadata>"
      @pub_xml = "<publicObject id='druid:#{@fake_druid}'>#{@cntnt_md_xml}</publicObject>"
      @ng_pub_xml = Nokogiri::XML(@pub_xml)
    end
    before(:each) do
      @hdor_client = double()
      @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      @hdor_client.stub(:public_xml).with(@fake_druid).and_return(@ng_pub_xml)
      @sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
    end

    it "content_md should get the contentMetadata from the public_xml" do
      content_md = @sdb.send(:content_md)
      content_md.should be_an_instance_of(Nokogiri::XML::Element)
      content_md.name.should == 'contentMetadata'
# NOTE:  the below isn't working -- probably due to Nokogiri attribute bug introduced      
  #    content_md.should be_equivalent_to(@cntnt_md_xml)
    end
    it "dor_content_type should be the value of the type attribute on the contentMetadata element" do
      @sdb.send(:dor_content_type).should == @cntnt_md_type
    end
    
    context "format" do
      it "format should be Image for contentMetadata type of image" do
        @sdb.format.should == 'Image'
      end
      it "should log an error message for an unrecognized contentMetadata type" do
        @sdb.stub(:dor_content_type).and_return('bogus')
        @sdb.logger.should_receive(:warn).with(/unrecognized DOR content type.*bogus/)
        @sdb.format
      end
    end
    
    context "display_type" do
      it "should be 'collection' if solr_doc_builder.collection?" do
        coll_mods_xml = "<mods #{@ns_decl}><typeOfResource collection='yes'/><note>hi</note></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(coll_mods_xml))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil)
        sdb.display_type.should == 'collection'
      end
      it "should be the same as <contentMetadata> type attribute if it's not a collection" do
        # NOTE: from the contentMetadata, not the mods
        m = "<mods #{@ns_decl}><typeOfResource>sound recording</typeOfResource></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil)
        sdb.display_type.should == @cntnt_md_type
        sdb.stub(:dor_content_type).and_return('bogus')
        sdb.display_type.should == 'bogus'
      end
      it "should log an error message if contentMetadata has no type" do
        @sdb.stub(:dor_content_type).and_return(nil)
        @sdb.logger.should_receive(:warn).with(/has no DOR content type/)
        @sdb.display_type
      end
    end
  end # fields from and methods pertaining to contentMetadata
  
  context "fields from and methods pertaining to rels-ext" do
    before(:each) do
      @hdor_client = double()
      @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
    end
    context "collection druids" do
      it "collection_druids look for the object's collection druids in the rels-ext in the public_xml" do
        coll_druid = 'ww121ss5000'
        rels_ext_xml = "<rdf:RDF  xmlns:fedora='info:fedora/fedora-system:def/relations-external#' xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'>
          <rdf:Description rdf:about='info:fedora/druid:#{@fake_druid}'>
            <fedora:isMemberOfCollection rdf:resource='info:fedora/druid:#{coll_druid}'/>
          </rdf:Description></rdf:RDF>"
        pub_xml = Nokogiri::XML("<publicObject id='druid:#{@fake_druid}'>#{rels_ext_xml}</publicObject>")
        @hdor_client.stub(:public_xml).with(@fake_druid).and_return(pub_xml)
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil)
        sdb.collection_druids.should == [coll_druid]
      end
      it "collection_druids should get multiple collection druids when they exist" do
        coll_druid = 'ww121ss5000'
        coll_druid2 = 'ww121ss5001'
        rels_ext_xml = "<rdf:RDF  xmlns:fedora='info:fedora/fedora-system:def/relations-external#' xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'>
          <rdf:Description rdf:about='info:fedora/druid:#{@fake_druid}'>
            <fedora:isMemberOfCollection rdf:resource='info:fedora/druid:#{coll_druid}'/>
            <fedora:isMemberOfCollection rdf:resource='info:fedora/druid:#{coll_druid2}'/>
          </rdf:Description></rdf:RDF>"
        pub_xml = Nokogiri::XML("<publicObject id='druid:#{@fake_druid}'>#{rels_ext_xml}</publicObject>")
        @hdor_client.stub(:public_xml).with(@fake_druid).and_return(pub_xml)
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil)
        sdb.collection_druids.should == [coll_druid, coll_druid2]
      end
      it "collection_druids should be nil when no isMemberOf relationships exist" do
        coll_druid = 'ww121ss5000'
        rels_ext_xml = "<rdf:RDF  xmlns:fedora='info:fedora/fedora-system:def/relations-external#' xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'>
          <rdf:Description rdf:about='info:fedora/druid:#{@fake_druid}'>
          </rdf:Description></rdf:RDF>"
        pub_xml = Nokogiri::XML("<publicObject id='druid:#{@fake_druid}'>#{rels_ext_xml}</publicObject>")
        @hdor_client.stub(:public_xml).with(@fake_druid).and_return(pub_xml)
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, nil)
        sdb.collection_druids.should == nil
      end
    end # collection druids    
  end # fields from and methods pertaining to rels-ext
  
  # --------------------------------------------------------------------------------------

  context "pub date fields" do
    it "pub_date" do
      pending "to be implemented"
    end
    it "pub_date_search should not be populated - it is a copy field" do
      pending "to be implemented"
    end
  end
  
  context "subject fields" do
    context "topic fields" do
      it "topic_search" do
        pending "to be implemented"
      end
      it "topic_display should not be populated - it is a copy field" do
        pending "to be implemented"
      end

    end

    context "era fields" do

    end
    context "geographic fields" do
      it "geographic_search" do
        pending "to be implemented"
      end
      it "geographic_facet??" do
        pending "to be implemented"
      end
    end
    
    it "subject_other_search" do
      pending "to be implemented"
    end
    it "subject_other_display should not be populated - it is a copy field" do
      pending "to be implemented"
    end
  end

  context "other publication fields" do
    it "pub_search" do
      pending "to be implemented"
    end
    it "pub_display should not be populated - it is a copy field" do
      pending "to be implemented"
    end
    it "pub_country" do
      pending "to be implemented"
    end
  end

  it "access_condition_display" do
    pending "to be implemented"
  end
  
  it "physical_location_display" do
    pending "to be implemented"
  end
  
  context "abstract and summary fields" do
    it "summary_search" do
      pending "to be implemented"
    end
    it "summary_display should not be populated - it is a copy field" do
      pending "to be implemented"
    end
    
  end
end