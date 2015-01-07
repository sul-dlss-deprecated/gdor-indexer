require 'spec_helper'

describe GDor::Indexer do
  
  before(:all) do
    @config_yml_path = File.join(File.dirname(__FILE__), "..", "config", "walters_integration_spec.yml")
    @solr_yml_path = File.join(File.dirname(__FILE__), "..", "config", "solr.yml")
    @client_config_path = File.join(File.dirname(__FILE__), "..", "config", "dor-fetcher-client.yml")
    require 'yaml'
    @yaml = YAML.load_file(@config_yml_path)
    @ns_decl = "xmlns='#{Mods::MODS_NS}'"
    @fake_druid = 'oo000oo0000'
    @coll_druid_from_test_config = "ww121ss5000"
    @mods_xml = "<mods #{@ns_decl}><note>Indexer test</note></mods>"
    @ng_mods_xml =  Nokogiri::XML("<mods #{@ns_decl}><note>Indexer test</note></mods>")
    @pub_xml = "<publicObject id='druid#{@fake_druid}'></publicObject>"
    @ng_pub_xml = Nokogiri::XML("<publicObject id='druid#{@fake_druid}'></publicObject>")
  end
  before(:each) do
    @indexer = GDor::Indexer.new(@config_yml_path, @client_config_path, @solr_yml_path) do |config|
      config.whitelist = ["druid:ww121ss5000"]
    end
    @hdor_client = @indexer.send(:harvestdor_client)
    allow(@hdor_client).to receive(:public_xml).and_return(@ng_pub_xml)
    allow(@indexer.solr_client).to receive(:add)
  end
  
  let :resource do
    r = Harvestdor::Indexer::Resource.new(double, @fake_druid)
    allow(r).to receive(:collections).and_return []
    allow(r).to receive(:mods).and_return Nokogiri::XML(@mods_xml)
    allow(r).to receive(:public_xml).and_return Nokogiri::XML(@pub_xml)
    allow(r).to receive(:public_xml?).and_return true
    allow(r).to receive(:content_metadata).and_return nil
    r
  end
  
  let :collection do
    r = Harvestdor::Indexer::Resource.new(double, @coll_druid_from_test_config)
    allow(r).to receive(:collections).and_return []
    allow(r).to receive(:mods).and_return Nokogiri::XML(@mods_xml)
    allow(r).to receive(:public_xml).and_return Nokogiri::XML(@pub_xml)
    allow(r).to receive(:public_xml?).and_return true
    allow(r).to receive(:content_metadata).and_return nil
    allow(r).to receive(:identity_md_obj_label).and_return ""
    r
  end

  context "logging" do
    it "should write the log file to the directory indicated by log_dir" do
      @indexer.logger.info("walters_integration_spec logging test message")
      expect(File).to exist(File.join(@yaml['harvestdor']['log_dir'], @yaml['harvestdor']['log_name']))
    end
  end
  
  context "#index_item" do
    context "merge or not?" do
      it "uses @indexer.record_merger if there is a catkey" do
        ckey = '666'
        sdb = double
        allow(sdb).to receive(:catkey).and_return(ckey)
        allow(sdb).to receive(:doc_hash).and_return(GDor::Indexer::SolrDocHash.new)
        allow(sdb).to receive(:collections)
        allow(sdb).to receive(:public_xml)
        allow(sdb).to receive(:display_type)
        allow(sdb).to receive(:file_ids)
        allow(sdb.doc_hash).to receive(:validate_mods).and_return([])
        allow(GDor::Indexer::SolrDocBuilder).to receive(:new).and_return(sdb)
        expect(@indexer.record_merger).to receive(:merge_and_index).with(ckey, instance_of(GDor::Indexer::SolrDocHash))
        @indexer.index_item resource
      end
      it "does not use @indexer.record_merger if there isn't a catkey" do
        sdb = double
        allow(sdb).to receive(:catkey).and_return(nil)
        allow(sdb).to receive(:public_xml)
        allow(sdb).to receive(:doc_hash).and_return(GDor::Indexer::SolrDocHash.new)
        allow(sdb).to receive(:coll_druids_from_rels_ext)
        allow(sdb).to receive(:display_type)
        allow(sdb).to receive(:file_ids)
        allow(sdb.doc_hash).to receive(:validate_mods).and_return([])
        allow(GDor::Indexer::SolrDocBuilder).to receive(:new).and_return(sdb)
        expect(@indexer.record_merger).not_to receive(:merge_and_index)
        expect(@indexer.solr_client).to receive(:add)
        @indexer.index_item resource
      end
      context "config.merge_policy" do
        before(:each) do
          @sdb = double
          allow(@sdb).to receive(:coll_druids_from_rels_ext)
          allow(@sdb).to receive(:public_xml)
          allow(@sdb).to receive(:display_type)
          allow(@sdb).to receive(:file_ids)
          # for unmerged items only
          allow(@sdb).to receive(:doc_hash).and_return(GDor::Indexer::SolrDocHash.new)
          allow(@sdb.doc_hash).to receive(:validate_mods).and_return([])
        end
        context "have catkey" do
          before(:each) do
            @ckey = '666'
            allow(@sdb).to receive(:catkey).and_return(@ckey)
            allow(GDor::Indexer::SolrDocBuilder).to receive(:new).and_return(@sdb)
          end
          context "merge_policy 'always'" do
            it "uses @indexer.record_merger if SW Solr index has record" do
              @indexer.config[:merge_policy] = 'always'
              expect(@indexer.record_merger).to receive(:merge_and_index).with(@ckey, instance_of(GDor::Indexer::SolrDocHash))
              @indexer.index_item resource
            end
            it "fails with error message if no record in SW Solr index" do
              @indexer.config[:merge_policy] = 'always'
              expect(@indexer.record_merger).to receive(:fetch_sw_solr_input_doc).with(@ckey).and_return(nil)
              expect(@indexer.record_merger).to receive(:merge_and_index).with(@ckey, instance_of(GDor::Indexer::SolrDocHash)).and_call_original
              expect(@indexer.logger).to receive(:error).with("#{@fake_druid} NOT INDEXED:  MARC record #{@ckey} not found in SW Solr index (may be shadowed in Symphony) and merge_policy set to 'always'")
              expect(@indexer.solr_client).not_to receive(:add)
              @indexer.index_item resource
            end
          end
          context "merge_policy 'never'" do
            it "does not use @indexer.record_merger and prints warning message" do
              @indexer.config[:merge_policy] = 'never'
              expect(@indexer.record_merger).not_to receive(:merge_and_index)
              expect(@indexer.logger).to receive(:warn).with("#{@fake_druid} to be indexed from MODS; has ckey #{@ckey} but merge_policy is 'never'")
              expect(@indexer.solr_client).to receive(:add)
              @indexer.index_item resource
            end
          end
          context "merge_policy not set" do
            it "uses @indexer.record_merger if SW Solr index has record" do
              @indexer.config[:merge_policy] = nil
              expect(@indexer.record_merger).to receive(:merge_and_index).with(@ckey, instance_of(GDor::Indexer::SolrDocHash))
              @indexer.index_item resource
            end
            it "falls back to MODS with error message if no record in SW Solr index" do
              @indexer.config[:merge_policy] = nil
              allow(@indexer.record_merger).to receive(:fetch_sw_solr_input_doc).with(@ckey).and_return(nil)
              expect(@indexer.record_merger).to receive(:merge_and_index).with(@ckey, instance_of(GDor::Indexer::SolrDocHash)).and_call_original
              expect(@indexer.logger).to receive(:error).with("#{@fake_druid} to be indexed from MODS:  MARC record #{@ckey} not found in SW Solr index (may be shadowed in Symphony)")
              expect(@indexer.solr_client).to receive(:add)
              @indexer.index_item resource
            end
          end
        end # have catkey
        context "no catkey" do
          before(:each) do
            allow(@sdb).to receive(:catkey).and_return(nil)
            allow(GDor::Indexer::SolrDocBuilder).to receive(:new).and_return(@sdb)
          end
          it "merge_policy 'always' doesn't use the MODS and prints error message" do
            @indexer.config[:merge_policy] = 'always'
            expect(@indexer.record_merger).not_to receive(:merge_and_index)
            expect(@indexer.logger).to receive(:error).with("#{@fake_druid} NOT INDEXED:  no ckey found and merge_policy set to 'always'")
            expect(@indexer.solr_client).not_to receive(:add)
            @indexer.index_item resource
          end
          it "merge_policy 'never' uses the MODS without error message" do
            @indexer.config[:merge_policy] = 'never'
            expect(@indexer.record_merger).not_to receive(:merge_and_index)
            expect(@indexer.logger).not_to receive(:error)
            expect(@indexer.solr_client).to receive(:add)
            @indexer.index_item resource
          end
          it "merge_policy not set uses the MODS without error message" do
            expect(@indexer.record_merger).not_to receive(:merge_and_index)
            expect(@indexer.logger).not_to receive(:error)
            expect(@indexer.solr_client).to receive(:add)
            @indexer.index_item resource
          end
        end # no catkey
      end # config.merge_policy
    end # merge or not?

    context "unmerged" do

      before(:each) do
        allow(@hdor_client).to receive(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      end
      it "calls Harvestdor::Indexer.solr_add" do
        expect(@indexer.solr_client).to receive(:add).with(hash_including(id: @fake_druid))
        @indexer.index_item resource
      end
      it "calls validate_item" do
        expect_any_instance_of(GDor::Indexer::SolrDocHash).to receive(:validate_item).and_return([])
        @indexer.index_item resource
      end
      it "calls GDor::Indexer::SolrDocBuilder.validate_mods" do
        allow_any_instance_of(GDor::Indexer::SolrDocHash).to receive(:validate_item).and_return([])
        expect_any_instance_of(GDor::Indexer::SolrDocHash).to receive(:validate_mods).and_return([])
        @indexer.index_item resource
      end
      it "calls add_coll_info" do
        expect(@indexer).to receive(:add_coll_info)
        @indexer.index_item resource
      end
      it "should have fields populated from the collection record" do
        sdb = double
        allow(sdb).to receive(:catkey).and_return(nil)
        allow(sdb).to receive(:doc_hash).and_return(GDor::Indexer::SolrDocHash.new)
        allow(sdb).to receive(:display_type)
        allow(sdb).to receive(:file_ids)
        allow(sdb.doc_hash).to receive(:validate_mods).and_return([])
        allow(GDor::Indexer::SolrDocBuilder).to receive(:new).and_return(sdb)
        allow(resource).to receive(:collections).and_return([double(druid: "foo", identity_md_obj_label: "bar")])
        expect(@indexer.solr_client).to receive(:add).with(hash_including(druid: @fake_druid, :collection => ['foo'], :collection_with_title => ['foo-|-bar']))
        @indexer.index_item resource
      end
      it "should have fields populated from the MODS" do
        title = 'fake title in mods'
        ng_mods = Nokogiri::XML("<mods #{@ns_decl}><titleInfo><title>#{title}</title></titleInfo></mods>")
        allow(resource).to receive(:mods).and_return(ng_mods)
        expect(@indexer.solr_client).to receive(:add).with(hash_including(id: @fake_druid, :title_display => title))
        @indexer.index_item resource
      end
      it "should populate url_fulltext field with purl page url" do
        expect(@indexer.solr_client).to receive(:add).with(hash_including(id: @fake_druid, :url_fulltext => "#{@yaml['harvestdor']['purl']}/#{@fake_druid}"))
        @indexer.index_item resource
      end
      it "should populate druid and access_facet fields" do
        expect(@indexer.solr_client).to receive(:add).with(hash_including(id: @fake_druid, :druid => @fake_druid, :access_facet => 'Online'))
        @indexer.index_item resource
      end
      it "should populate display_type field by calling display_type method" do
        expect_any_instance_of(GDor::Indexer::SolrDocBuilder).to receive(:display_type).and_return("foo")
        expect(@indexer.solr_client).to receive(:add).with(hash_including(id: @fake_druid, :display_type => "foo"))
        @indexer.index_item resource
      end
      it "should populate file_id field by calling file_ids method" do
        expect_any_instance_of(GDor::Indexer::SolrDocBuilder).to receive(:file_ids).at_least(1).times.and_return(["foo"])
        expect(@indexer.solr_client).to receive(:add).with(hash_including(id: @fake_druid, :file_id => ["foo"]))
        @indexer.index_item resource
      end
      it "should populate building_facet field with Stanford Digital Repository" do
        expect(@indexer.solr_client).to receive(:add).with(hash_including(id: @fake_druid, :building_facet => 'Stanford Digital Repository'))
        @indexer.index_item resource
      end
    end # unmerged item

    context "merged with marc" do
      before(:each) do
        @ickey = '999'
        @sdb = double
        allow(@sdb).to receive(:catkey).and_return(@ickey)
        allow(@sdb).to receive(:coll_druids_from_rels_ext).and_return(['foo'])
        allow(@sdb).to receive(:doc_hash).and_return(GDor::Indexer::SolrDocHash.new)
        allow(@sdb).to receive(:display_type).and_return('fiddle')
        allow(@sdb).to receive(:file_ids).and_return(['dee', 'dum'])
        allow(@sdb.doc_hash).to receive(:validate_mods).and_return([])
        allow(GDor::Indexer::SolrDocBuilder).to receive(:new).and_return(@sdb)
        allow(@indexer).to receive(:identity_md_obj_label).with('foo').and_return('bar')
        allow(@indexer).to receive(:coll_catkey).and_return(nil)
        @indexer.config[:merge_policy] = nil
      end
      it "calls @indexer.record_merger.merge_and_index with gdor fields and item specific fields" do
        expect(@indexer.record_merger).to receive(:merge_and_index).with(@ickey, hash_including(:display_type => 'fiddle',
                                                                                  :file_id => ['dee', 'dum'],
                                                                                  :druid => @fake_druid,
                                                                                  :url_fulltext => "#{@yaml['harvestdor']['purl']}/#{@fake_druid}",
                                                                                  :access_facet => 'Online',
                                                                                  :collection => ['foo'],
                                                                                  :collection_with_title => ['foo-|-bar'],
                                                                                  :building_facet => 'Stanford Digital Repository' ))
        @indexer.index_item resource
      end
      it "calls add_coll_info" do
        expect(@indexer).to receive(:add_coll_info).at_least(1).times
        expect(@indexer.record_merger).to receive(:merge_and_index)
        @indexer.index_item resource
      end
      it "calls validate_item" do
        expect_any_instance_of(GDor::Indexer::SolrDocHash).to receive(:validate_item).at_least(1).times.and_return([])
        expect(@indexer.record_merger).to receive(:merge_and_index)
        @indexer.index_item resource
      end
      it "should add a doc to Solr with item fields added" do
        expect_any_instance_of(SolrjWrapper).to receive(:add_doc_to_ix).with(hash_including('display_type', 'file_id', 'druid', 'collection', 'collection_with_title', 'building_facet'), @ickey)
        @indexer.index_item resource
      end
    end # merged item
  end # index_item 

  context "#index_coll_obj_per_config" do
    context "merge or not?" do
      it "uses @indexer.record_merger if there is a catkey" do
        ckey = '666'
        allow(@indexer).to receive(:coll_catkey).and_return(ckey)
        expect(@indexer.record_merger).to receive(:merge_and_index)
        @indexer.index_coll_obj_per_config collection
      end
      it "does not use @indexer.record_merger if there isn't a catkey" do
        allow(@indexer).to receive(:coll_catkey).and_return(nil)
        expect(@indexer.record_merger).not_to receive(:merge_and_index)
        allow_any_instance_of(GDor::Indexer::SolrDocBuilder).to receive(:doc_hash).and_return(GDor::Indexer::SolrDocHash.new) # speed up the test
        expect(@indexer.solr_client).to receive(:add)
        @indexer.index_coll_obj_per_config collection
      end
      before(:each) do
        @sdb = double
        allow(@sdb).to receive(:coll_druids_from_rels_ext)
        allow(@sdb).to receive(:public_xml)
        allow(@sdb).to receive(:display_type)
        allow(@sdb).to receive(:file_ids)
        # for unmerged items only
        allow(@sdb).to receive(:doc_hash).and_return(GDor::Indexer::SolrDocHash.new)
        allow(@sdb.doc_hash).to receive(:validate_mods).and_return([])
      end
      context "have catkey" do
        before(:each) do
          @ckey = '666'
          allow(@sdb).to receive(:catkey).and_return(@ckey)
          allow(GDor::Indexer::SolrDocBuilder).to receive(:new).and_return(@sdb)
        end
        shared_examples_for 'uses MARC if it can find it' do | policy |
          it "uses @indexer.record_merger if SW Solr index has record" do
            @indexer.config[:merge_policy] = policy
            expect(@indexer.record_merger).to receive(:merge_and_index).with(@ckey, instance_of(GDor::Indexer::SolrDocHash))
            @indexer.index_coll_obj_per_config collection
          end
          it "falls back to MODS with error message if no record in SW Solr index" do
            @indexer.config[:merge_policy] = policy
            expect(@indexer.record_merger).to receive(:fetch_sw_solr_input_doc).with(@ckey).and_return(nil)
            expect(@indexer.record_merger).to receive(:merge_and_index).with(@ckey, instance_of(GDor::Indexer::SolrDocHash)).and_call_original
            expect(@indexer.logger).to receive(:error).with("#{@coll_druid_from_test_config} to be indexed from MODS:  MARC record #{@ckey} not found in SW Solr index (may be shadowed in Symphony)")
            expect(@indexer.solr_client).to receive(:add)
            @indexer.index_coll_obj_per_config collection
          end
        end
        context "merge_policy 'always'" do
          it_behaves_like 'uses MARC if it can find it', 'always'
        end
        context "merge_policy 'never'" do
          it_behaves_like 'uses MARC if it can find it', 'never'
        end
        context "merge_policy not set" do
          it_behaves_like 'uses MARC if it can find it'
        end
      end # have catkey
      context "no catkey" do
        before(:each) do
          allow(@sdb).to receive(:catkey).and_return(nil)
          allow(GDor::Indexer::SolrDocBuilder).to receive(:new).and_return(@sdb)
        end
        shared_examples_for 'uses the MODS without error message' do | policy |
          it "" do
            @indexer.config[:merge_policy] = policy
            expect(@indexer.record_merger).not_to receive(:merge_and_index)
            expect(@indexer.logger).not_to receive(:error)
            expect(@indexer.solr_client).to receive(:add)
            @indexer.index_coll_obj_per_config collection
          end
        end
        context "merge_policy 'always'" do
          it_behaves_like 'uses the MODS without error message', 'always'
        end
        context "merge_policy 'never'" do
          it_behaves_like 'uses the MODS without error message', 'never'
        end
        context "merge_policy not set" do
          it_behaves_like 'uses the MODS without error message'
        end
      end # no catkey
    end # merge or not?
    
    context "unmerged" do
      before do

      end
      it "adds the collection doc to the index" do
        allow_any_instance_of(GDor::Indexer::SolrDocBuilder).to receive(:doc_hash).and_return(GDor::Indexer::SolrDocHash.new) # speed up the test
        expect(@indexer.solr_client).to receive(:add)
        @indexer.index_coll_obj_per_config collection
      end
      it "calls validate_collection" do
        doc_hash = GDor::Indexer::SolrDocHash.new
        allow_any_instance_of(GDor::Indexer::SolrDocBuilder).to receive(:doc_hash).and_return(doc_hash) # speed up the test
        expect(doc_hash).to receive(:validate_collection)
        @indexer.index_coll_obj_per_config collection
      end
      it "calls GDor::Indexer::SolrDocBuilder.validate_mods" do
        doc_hash = GDor::Indexer::SolrDocHash.new
        allow_any_instance_of(GDor::Indexer::SolrDocBuilder).to receive(:doc_hash).and_return(doc_hash) # speed up the test
        expect(doc_hash).to receive(:validate_mods)
        @indexer.index_coll_obj_per_config collection
      end
      context "display_type" do
        it "includes display_types from coll_display_types_from_items when the druid matches" do
          allow(@indexer).to receive(:coll_display_types_from_items).and_return({@coll_druid_from_test_config => ['image']})
          allow_any_instance_of(GDor::Indexer::SolrDocBuilder).to receive(:doc_hash).and_return(GDor::Indexer::SolrDocHash.new)
          expect(@indexer.solr_client).to receive(:add).with(hash_including(:display_type => ['image']))
          @indexer.index_coll_obj_per_config collection
        end
        it "does not include display_types from coll_display_types_from_items when the druid doesn't match" do
          allow(@indexer).to receive(:coll_display_types_from_items).and_return({'foo' => ['image']})
          allow_any_instance_of(GDor::Indexer::SolrDocBuilder).to receive(:doc_hash).and_return(GDor::Indexer::SolrDocHash.new)
          expect(@indexer.solr_client).not_to receive(:add).with(hash_including(:display_type => ['image']))
          @indexer.index_coll_obj_per_config collection
        end
      end
      it "populates druid and access_facet fields" do
        expect(@indexer.solr_client).to receive(:add).with(hash_including(:druid => @coll_druid_from_test_config, 
                                                                                        :access_facet => 'Online'))
        @indexer.index_coll_obj_per_config collection
      end
      it "populates url_fulltext field with purl page url" do
        expect(@indexer.solr_client).to receive(:add).with(hash_including(:url_fulltext => "#{@yaml['harvestdor']['purl']}/#{@coll_druid_from_test_config}"))
        @indexer.index_coll_obj_per_config collection
      end
      it "collection_type should be 'Digital Collection'" do
        allow_any_instance_of(GDor::Indexer::SolrDocBuilder).to receive(:doc_hash).and_return(GDor::Indexer::SolrDocHash.new) # speed up the test
        expect(@indexer.solr_client).to receive(:add).with(hash_including(:collection_type => 'Digital Collection'))
        @indexer.index_coll_obj_per_config collection
      end
      context "add format_main_ssim Archive/Manuscript" do
        it "no other values" do
          allow_any_instance_of(GDor::Indexer::SolrDocBuilder).to receive(:doc_hash).and_return(GDor::Indexer::SolrDocHash.new)
          expect(@indexer.solr_client).to receive(:add).with(hash_including(:format_main_ssim => 'Archive/Manuscript'))
          @indexer.index_coll_obj_per_config collection
        end
        it "other values present" do
          allow_any_instance_of(GDor::Indexer::SolrDocBuilder).to receive(:doc_hash).and_return(GDor::Indexer::SolrDocHash.new({:format_main_ssim => ['Image', 'Video']}))
          expect(@indexer.solr_client).to receive(:add).with(hash_including(:format_main_ssim => ['Image', 'Video', 'Archive/Manuscript']))
          @indexer.index_coll_obj_per_config collection
        end
        it "already has values Archive/Manuscript" do
          allow_any_instance_of(GDor::Indexer::SolrDocBuilder).to receive(:doc_hash).and_return(GDor::Indexer::SolrDocHash.new({:format_main_ssim => 'Archive/Manuscript'}))
          expect(@indexer.solr_client).to receive(:add).with(hash_including(:format_main_ssim => ['Archive/Manuscript']))
          @indexer.index_coll_obj_per_config collection
        end
      end
      it "populates building_facet field with Stanford Digital Repository" do
        expect(@indexer.solr_client).to receive(:add).with(hash_including(:building_facet => 'Stanford Digital Repository'))
        @indexer.index_coll_obj_per_config collection
      end
    end # unmerged collection

    context "merged with marc" do
      before(:each) do
        @ckey = '666'
        allow(@indexer).to receive(:coll_catkey).and_return(@ckey)
      end
      it "should call @indexer.record_merger.merge_and_index with gdor fields and collection specific fields" do
        allow(@indexer).to receive(:coll_display_types_from_items).and_return({@coll_druid_from_test_config => ['image']})
        expect(@indexer.record_merger).to receive(:merge_and_index).with(@ckey, hash_including(:display_type => ['image'],
                                                                                :druid => @coll_druid_from_test_config,
                                                                                :url_fulltext => "#{@yaml['harvestdor']['purl']}/#{@coll_druid_from_test_config}",
                                                                                :access_facet => 'Online', 
                                                                                :collection_type => "Digital Collection",
                                                                                :format_main_ssim => "Archive/Manuscript",
                                                                                :building_facet => 'Stanford Digital Repository'))
        @indexer.index_coll_obj_per_config collection
      end
      it "should call @indexer.record_merger.add_hash_to_solr_input_doc with gdor fields and collection specific fields" do
        allow(@indexer).to receive(:coll_display_types_from_items).and_return({@coll_druid_from_test_config => ['image']})
        allow(@indexer.record_merger).to receive(:merge_and_index).and_call_original
        expect(@indexer.record_merger).to receive(:add_hash_to_solr_input_doc).with(anything, 
                                                                          hash_including(:display_type => ['image'],
                                                                                :druid => @coll_druid_from_test_config,
                                                                                :url_fulltext => "#{@yaml['harvestdor']['purl']}/#{@coll_druid_from_test_config}",
                                                                                :access_facet => 'Online', 
                                                                                :collection_type => "Digital Collection",
                                                                                :format_main_ssim => "Archive/Manuscript",
                                                                                :building_facet => 'Stanford Digital Repository'))
        @indexer.index_coll_obj_per_config collection
      end
      it "validates the collection doc via validate_collection" do
        expect_any_instance_of(GDor::Indexer::SolrDocHash).to receive(:validate_collection)
        @indexer.index_coll_obj_per_config collection
      end
      it "should add a doc to Solr with gdor fields and collection specific fields" do
        allow(@indexer).to receive(:coll_display_types_from_items).and_return({@coll_druid_from_test_config => ['image']})
        expect_any_instance_of(SolrjWrapper).to receive(:add_doc_to_ix).with(
                hash_including('druid', 'display_type', 'url_fulltext', 'access_facet', 'collection_type', 'format', 'building_facet'), @ckey)
        @indexer.index_coll_obj_per_config collection
      end
      context "add format_main_ssim Archive/Manuscript" do
        before(:each) do
          @solr_input_doc = @indexer.record_merger.fetch_sw_solr_input_doc @key
          allow(@indexer).to receive(:coll_display_types_from_items).and_return({@coll_druid_from_test_config => ['image']})
        end
        it "no other values" do
          expect_any_instance_of(SolrjWrapper).to receive(:add_doc_to_ix) do | sid_arg, ckey_arg |
            expect(sid_arg["format_main_ssim"].getValue).to eq('Archive/Manuscript')
          end
          @indexer.index_coll_obj_per_config collection
        end
        it "other values present" do
          expect_any_instance_of(SolrjWrapper).to receive(:add_doc_to_ix) do | sid_arg, ckey_arg |
            expect(sid_arg["format_main_ssim"].getValue).to match_array ['Image', 'Video', 'Archive/Manuscript']
          end
          @indexer.index_coll_obj_per_config collection
        end
        it "already has value Archive/Manuscript" do
          expect_any_instance_of(SolrjWrapper).to receive(:add_doc_to_ix) do | sid_arg, ckey_arg |
            expect(sid_arg["format_main_ssim"].getValue).to eq('Archive/Manuscript')
          end
          @indexer.index_coll_obj_per_config collection
        end
      end
    end # merged collection
  end #  index_coll_obj_per_config
  
  context "#add_coll_info and supporting methods" do
    before(:each) do
      @coll_druids_array = [collection]
    end

    it "should add no collection field values to doc_hash if there are none" do
      doc_hash = GDor::Indexer::SolrDocHash.new({})
      @indexer.add_coll_info(doc_hash, nil)
      expect(doc_hash[:collection]).to be_nil
      expect(doc_hash[:collection_with_title]).to be_nil
      expect(doc_hash[:display_type]).to be_nil
    end
    
    context "collection field" do
      it "should be added field to doc hash" do
        doc_hash = GDor::Indexer::SolrDocHash.new({})
        @indexer.add_coll_info(doc_hash, @coll_druids_array)
        expect(doc_hash[:collection]).to match_array [@coll_druid_from_test_config]
      end
      it "should add two values to doc_hash when object belongs to two collections" do
        coll_druid1 = 'oo111oo2222'
        coll_druid2 = 'oo333oo4444'
        doc_hash = GDor::Indexer::SolrDocHash.new({})
        @indexer.add_coll_info(doc_hash, [double(druid: coll_druid1, public_xml: @ng_pub_xml, identity_md_obj_label: ""), double(druid: coll_druid2, public_xml: @ng_pub_xml, identity_md_obj_label: "")])
        expect(doc_hash[:collection]).to match_array [coll_druid1, coll_druid2]
      end
      it "should have the ckey when the collection record is merged" do
        @catkey_id_md = Nokogiri::XML("<publicObject><identityMetadata><otherId name=\"catkey\">666</otherId></identityMetadata></publicObject>")
        doc_hash = GDor::Indexer::SolrDocHash.new({})
        @indexer.add_coll_info(doc_hash, [double(druid: "some:druid", public_xml: @catkey_id_md, identity_md_obj_label: "")])
        expect(doc_hash[:collection]).to match_array ['666']
      end
      # other tests show it uses druid when coll rec isn't merged
    end

    context "collection_with_title field" do
      it "should be added to doc_hash" do
        coll_druid = 'oo000oo1234'
        doc_hash = GDor::Indexer::SolrDocHash.new({})
        @indexer.add_coll_info(doc_hash, [double(druid: coll_druid, public_xml: @ng_pub_xml, identity_md_obj_label: "zzz")])
        expect(doc_hash[:collection_with_title]).to match_array ["#{coll_druid}-|-zzz"]
      end
      it "should add two values to doc_hash when object belongs to two collections" do
        coll_druid1 = 'oo111oo2222'
        coll_druid2 = 'oo333oo4444'
        doc_hash = GDor::Indexer::SolrDocHash.new({})
        @indexer.add_coll_info(doc_hash, [double(druid: coll_druid1, public_xml: @ng_pub_xml, identity_md_obj_label: "foo"), double(druid: coll_druid2, public_xml: @ng_pub_xml, identity_md_obj_label: "bar")])
        expect(doc_hash[:collection_with_title]).to match_array ["#{coll_druid1}-|-foo", "#{coll_druid2}-|-bar"]
      end
      it "should have the ckey when the collection record is merged" do
        @catkey_id_md = Nokogiri::XML("<publicObject><identityMetadata><otherId name=\"catkey\">666</otherId></identityMetadata></publicObject>")
        doc_hash = GDor::Indexer::SolrDocHash.new({})
        @indexer.add_coll_info(doc_hash, [double(druid: "some:druid", public_xml: @catkey_id_md, identity_md_obj_label: "zzz")])
        expect(doc_hash[:collection_with_title]).to match_array ['666-|-zzz']
      end
      # other tests show it uses druid when coll rec isn't merged
    end

    context "#coll_display_types_from_items" do
      before(:each) do
        allow(@hdor_client).to receive(:public_xml).and_return(@ng_pub_xml)
        @indexer.coll_display_types_from_items(@coll_druid_from_test_config)
      end
      it "gets single item display_type for single collection (and no dups)" do
        allow(@indexer).to receive(:identity_md_obj_label)
        doc_hash = GDor::Indexer::SolrDocHash.new({:display_type => 'image'})
        @indexer.add_coll_info(doc_hash, @coll_druids_array)
        doc_hash = GDor::Indexer::SolrDocHash.new({:display_type => 'image'})
        @indexer.add_coll_info(doc_hash, @coll_druids_array)
        expect(@indexer.coll_display_types_from_items(@coll_druid_from_test_config)).to match_array ['image']
      end
      it "gets multiple formats from multiple items for single collection" do
        allow(@indexer).to receive(:identity_md_obj_label)
        doc_hash = GDor::Indexer::SolrDocHash.new({:display_type => 'image'})
        @indexer.add_coll_info(doc_hash, @coll_druids_array)
        doc_hash = GDor::Indexer::SolrDocHash.new({:display_type => 'file'})
        @indexer.add_coll_info(doc_hash, @coll_druids_array)
        expect(@indexer.coll_display_types_from_items(@coll_druid_from_test_config)).to match_array ['image', 'file']
      end
    end # coll_display_types_from_items
  end #add_coll_info

  context "#num_found_in_solr" do
    before :each do 
      @unmerged_collection_response = {'response' => {'numFound'=>'1','docs'=>[{'id'=>'dm212rn7381', 'url_fulltext' => ['http://purl.stanford.edu/dm212rn7381']}]}}
      @merged_collection_response = {'response' => {'numFound'=>'1','docs'=>[{'id'=>'666', 'url_fulltext' => ['http://purl.stanford.edu/dm212rn7381']}]}}
      @bad_collection_response = {'response' => {'numFound'=>'1','docs'=>[{'id'=>'dm212rn7381'}]}}
      @item_response = {'response' => {'numFound'=>'265','docs'=>[{'id'=>'dm212rn7381'}]}}
    end

    it 'should count the items and the collection object in the solr index after indexing (merged)' do
      allow(@indexer).to receive(:coll_catkey).and_return("666")
      allow(@indexer).to receive(:coll_druid_from_config).and_return('dm212rn7381')
      allow(@indexer.solr_client).to receive(:get) do |wt, params|
        if params[:params][:fl].include?('url_fulltext')
          @merged_collection_response
        else
          @item_response
        end
      end
      expect(@indexer.num_found_in_solr("666")).to eq(266)
    end
    it 'should count the items and the collection object in the solr index after indexing (unmerged)' do
      allow(@indexer).to receive(:coll_catkey).and_return(nil)
      allow(@indexer).to receive(:coll_druid_from_config).and_return('dm212rn7381')
      allow(@indexer.solr_client).to receive(:get) do |wt, params|
        if params[:params][:fl].include?('url_fulltext')
          @unmerged_collection_response
        else
          @item_response
        end
      end
      expect(@indexer.num_found_in_solr("dm212rn7381")).to eq(266)
    end
    it 'should verify the collection object has a purl' do
      allow(@indexer.solr_client).to receive(:get) do |wt, params|
        if params[:qt]
          @bad_collection_response
        else
          @item_response
        end
        expect(@indexer.num_found_in_solr("dm212rn7381")).to eq(265)
      end
    end
  end # num_found_in_solr

  context "#email_results" do
    require 'socket'
    before(:each) do
      allow(Socket).to receive(:gethostname).and_return("harvestdor-specs")
      allow(@indexer).to receive(:record_count_msgs).and_return([])
    end
    it "email body includes coll id" do
      expect(@indexer).to receive(:send_email) do | email, hash |
        expect(hash[:body]).to match /testcoll indexed coll record is: ww121ss5000/
      end
      @indexer.send(:email_results)
    end
    it "email body includes coll title" do
      allow(@indexer).to receive(:coll_druid_2_title_hash).and_return({'ww121ss5000'=>"foo"})
      expect(@indexer).to receive(:send_email) do | email, hash |
        expect(hash[:body]).to match /testcoll indexed coll record is: ww121ss5000/
      end
      @indexer.send(:email_results)
    end
    it "email body includes Solr url for items" do
      expect(@indexer).to receive(:send_email) do | email, hash |
        expect(hash[:body]).to match /Solr query for items: http:\/\/solr.baseurl.org\/select\?fq=collection:ww121ss5000&fl=id,title_245a_display/
      end
      @indexer.send(:email_results)
    end
    it "email body includes failed to index druids" do
      @indexer.instance_variable_set(:@druids_failed_to_ix, ['a', 'b'])
      expect(@indexer).to receive(:send_email) do | email, hash |
        expect(hash[:body]).to match /records that may have failed to index \(merged recs as druids, not ckeys\): \na\nb\n\n/
      end
      @indexer.send(:email_results)
    end
    it "email includes reference to full log" do
      expect(@indexer).to receive(:send_email) do | email, hash |
        expect(hash[:body]).to match /full log is at gdor_indexer\/shared\/spec\/test_logs\/testcoll\.log on harvestdor-specs/
      end
      @indexer.send(:email_results)
    end
  end

  context "skip heartbeat" do
    it "allows me to use a fake url for dor-fetcher-client" do
      expect {GDor::Indexer.new(@config_yml_path, @client_config_path, @solr_yml_path)}.not_to raise_error
    end
  end

end
