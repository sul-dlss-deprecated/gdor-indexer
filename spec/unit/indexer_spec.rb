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
    @ng_mods_xml =  Nokogiri::XML("<mods #{@ns_decl}><note>Indexer test</note></mods>")
    @ng_pub_xml = Nokogiri::XML("<publicObject id='druid#{@fake_druid}'></publicObject>")
  end
  before(:each) do
    @indexer = GDor::Indexer.new(@config_yml_path, @client_config_path, @solr_yml_path)
    @hdor_client = @indexer.send(:harvestdor_client)
    allow(@hdor_client).to receive(:public_xml).and_return(@ng_pub_xml)
    allow(@indexer.solr_client).to receive(:add)
  end
  
  context "logging" do
    it "should write the log file to the directory indicated by log_dir" do
      @indexer.logger.info("walters_integration_spec logging test message")
      expect(File).to exist(File.join(@yaml['log_dir'], @yaml['log_name']))
    end
  end

  it "should initialize the harvestdor_client from the config" do
    expect(@hdor_client).to be_an_instance_of(Harvestdor::Client)
    expect(@hdor_client.config.default_set).to eq(@yaml['default_set'])
  end
  
  context "#harvest_and_index" do
    before(:each) do
      allow(@indexer).to receive(:coll_druid_from_config).and_return(@fake_druid)
      allow(@hdor_client).to receive(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      allow(@hdor_client).to receive(:public_xml).with(@fake_druid).and_return(@ng_pub_xml)
      @coll_sdb = GDor::Indexer::SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
      allow(@coll_sdb).to receive(:coll_object?).and_return(true)
      allow(@indexer).to receive(:num_found_in_solr)
      allow(@indexer).to receive(:coll_sdb).and_return(@coll_sdb)
    end
    it "if coll rec from config harvested relationship isn't a coll rec per identity metadata, no further indexing should occur" do
      allow(@coll_sdb).to receive(:coll_object?).and_return(false)
      allow(@indexer).to receive(:coll_sdb).and_return(@coll_sdb)
      expect(@indexer.logger).to receive(:fatal).with("#{@fake_druid} is not a collection object!! (per identityMetaadata)  Ending indexing.")
      expect(@indexer).not_to receive(:index_item)
      expect(@indexer).not_to receive(:index_coll_obj_per_config)
      expect(@indexer.solr_client).not_to receive(:commit)
      @indexer.harvest_and_index
    end
    it "should call index_item for each druid" do
      expect_any_instance_of(Harvestdor::Indexer).to receive(:druids).at_least(1).times.and_return(['1', '2', '3'])
      expect(@indexer).to receive(:index_item).with('1')
      expect(@indexer).to receive(:index_item).with('2')
      expect(@indexer).to receive(:index_item).with('3')
      @indexer.harvest_and_index(true) # nocommit for ease of testing
    end
    it "should call index_coll_obj_per_config once for the coll druid from the config file" do
      expect_any_instance_of(Harvestdor::Indexer).to receive(:druids).at_least(1).times.and_return([])
      expect(@indexer).to receive(:index_coll_obj_per_config)
      @indexer.harvest_and_index(true) # nocommit for ease of testing
    end
  end # harvest_and_index
  
  context "#index_item" do

    context "merge or not?" do
      it "uses GDor::Indexer::RecordMerger if there is a catkey" do
        ckey = '666'
        sdb = double
        allow(sdb).to receive(:catkey).and_return(ckey)
        allow(sdb).to receive(:doc_hash).and_return(GDor::Indexer::SolrDocHash.new)
        allow(sdb).to receive(:coll_druids_from_rels_ext)
        allow(sdb).to receive(:public_xml)
        allow(sdb).to receive(:display_type)
        allow(sdb).to receive(:file_ids)
        allow(sdb.doc_hash).to receive(:validate_mods).and_return([])
        allow(GDor::Indexer::SolrDocBuilder).to receive(:new).and_return(sdb)
        expect(GDor::Indexer::RecordMerger).to receive(:merge_and_index).with(ckey, instance_of(GDor::Indexer::SolrDocHash))
        @indexer.index_item @fake_druid
      end
      it "does not use GDor::Indexer::RecordMerger if there isn't a catkey" do
        sdb = double
        allow(sdb).to receive(:catkey).and_return(nil)
        allow(sdb).to receive(:public_xml)
        allow(sdb).to receive(:doc_hash).and_return(GDor::Indexer::SolrDocHash.new)
        allow(sdb).to receive(:coll_druids_from_rels_ext)
        allow(sdb).to receive(:display_type)
        allow(sdb).to receive(:file_ids)
        allow(sdb.doc_hash).to receive(:validate_mods).and_return([])
        allow(GDor::Indexer::SolrDocBuilder).to receive(:new).and_return(sdb)
        expect(GDor::Indexer::RecordMerger).not_to receive(:merge_and_index)
        expect(@indexer.solr_client).to receive(:add)
        @indexer.index_item @fake_druid
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
            it "uses GDor::Indexer::RecordMerger if SW Solr index has record" do
              GDor::Indexer.config[:merge_policy] = 'always'
              expect(GDor::Indexer::RecordMerger).to receive(:merge_and_index).with(@ckey, instance_of(GDor::Indexer::SolrDocHash))
              @indexer.index_item @fake_druid
            end
            it "fails with error message if no record in SW Solr index" do
              GDor::Indexer.config[:merge_policy] = 'always'
              expect(GDor::Indexer::RecordMerger).to receive(:fetch_sw_solr_input_doc).with(@ckey).and_return(nil)
              expect(GDor::Indexer::RecordMerger).to receive(:merge_and_index).with(@ckey, instance_of(GDor::Indexer::SolrDocHash)).and_call_original
              expect(@indexer.logger).to receive(:error).with("#{@fake_druid} NOT INDEXED:  MARC record #{@ckey} not found in SW Solr index (may be shadowed in Symphony) and merge_policy set to 'always'")
              expect(@indexer.solr_client).not_to receive(:add)
              @indexer.index_item @fake_druid
            end
          end
          context "merge_policy 'never'" do
            it "does not use GDor::Indexer::RecordMerger and prints warning message" do
              GDor::Indexer.config[:merge_policy] = 'never'
              expect(GDor::Indexer::RecordMerger).not_to receive(:merge_and_index)
              expect(@indexer.logger).to receive(:warn).with("#{@fake_druid} to be indexed from MODS; has ckey #{@ckey} but merge_policy is 'never'")
              expect(@indexer.solr_client).to receive(:add)
              @indexer.index_item @fake_druid
            end
          end
          context "merge_policy not set" do
            it "uses GDor::Indexer::RecordMerger if SW Solr index has record" do
              GDor::Indexer.config[:merge_policy] = nil
              expect(GDor::Indexer::RecordMerger).to receive(:merge_and_index).with(@ckey, instance_of(GDor::Indexer::SolrDocHash))
              @indexer.index_item @fake_druid
            end
            it "falls back to MODS with error message if no record in SW Solr index" do
              GDor::Indexer.config[:merge_policy] = nil
              allow(GDor::Indexer::RecordMerger).to receive(:fetch_sw_solr_input_doc).with(@ckey).and_return(nil)
              expect(GDor::Indexer::RecordMerger).to receive(:merge_and_index).with(@ckey, instance_of(GDor::Indexer::SolrDocHash)).and_call_original
              expect(@indexer.logger).to receive(:error).with("#{@fake_druid} to be indexed from MODS:  MARC record #{@ckey} not found in SW Solr index (may be shadowed in Symphony)")
              expect(@indexer.solr_client).to receive(:add)
              @indexer.index_item @fake_druid
            end
          end
        end # have catkey
        context "no catkey" do
          before(:each) do
            allow(@sdb).to receive(:catkey).and_return(nil)
            allow(GDor::Indexer::SolrDocBuilder).to receive(:new).and_return(@sdb)
          end
          it "merge_policy 'always' doesn't use the MODS and prints error message" do
            GDor::Indexer.config[:merge_policy] = 'always'
            expect(GDor::Indexer::RecordMerger).not_to receive(:merge_and_index)
            expect(@indexer.logger).to receive(:error).with("#{@fake_druid} NOT INDEXED:  no ckey found and merge_policy set to 'always'")
            expect(@indexer.solr_client).not_to receive(:add)
            @indexer.index_item @fake_druid
          end
          it "merge_policy 'never' uses the MODS without error message" do
            GDor::Indexer.config[:merge_policy] = 'never'
            expect(GDor::Indexer::RecordMerger).not_to receive(:merge_and_index)
            expect(@indexer.logger).not_to receive(:error)
            expect(@indexer.solr_client).to receive(:add)
            @indexer.index_item @fake_druid
          end
          it "merge_policy not set uses the MODS without error message" do
            expect(GDor::Indexer::RecordMerger).not_to receive(:merge_and_index)
            expect(@indexer.logger).not_to receive(:error)
            expect(@indexer.solr_client).to receive(:add)
            @indexer.index_item @fake_druid
          end
        end # no catkey
      end # config.merge_policy
    end # merge or not?

    context "unmerged" do
      before(:each) do
        allow(@hdor_client).to receive(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      end
      it "calls Harvestdor::Indexer.solr_add" do
        expect_any_instance_of(Harvestdor::Indexer).to receive(:solr_add).with(instance_of(GDor::Indexer::SolrDocHash), @fake_druid)
        @indexer.index_item @fake_druid
      end
      it "calls validate_item" do
        expect_any_instance_of(GDor::Indexer::SolrDocHash).to receive(:validate_item).and_return([])
        @indexer.index_item @fake_druid
      end
      it "calls GDor::Indexer::SolrDocBuilder.validate_mods" do
        allow_any_instance_of(GDor::Indexer::SolrDocHash).to receive(:validate_item).and_return([])
        expect_any_instance_of(GDor::Indexer::SolrDocHash).to receive(:validate_mods).and_return([])
        @indexer.index_item @fake_druid
      end
      it "calls add_coll_info" do
        expect(@indexer).to receive(:add_coll_info)
        @indexer.index_item @fake_druid
      end
      it "should have fields populated from the collection record" do
        sdb = double
        allow(sdb).to receive(:catkey).and_return(nil)
        allow(sdb).to receive(:doc_hash).and_return(GDor::Indexer::SolrDocHash.new)
        allow(sdb).to receive(:display_type)
        allow(sdb).to receive(:file_ids)
        allow(sdb.doc_hash).to receive(:validate_mods).and_return([])
        allow(GDor::Indexer::SolrDocBuilder).to receive(:new).and_return(sdb)
        allow(sdb).to receive(:coll_druids_from_rels_ext).and_return(['foo'])
        allow(@indexer).to receive(:identity_md_obj_label).with('foo').and_return('bar')
        expect_any_instance_of(Harvestdor::Indexer).to receive(:solr_add).with(hash_including(:collection => ['foo'], 
                                                                                        :collection_with_title => ['foo-|-bar']), @fake_druid)
        @indexer.index_item @fake_druid
      end
      it "should have fields populated from the MODS" do
        title = 'fake title in mods'
        ng_mods = Nokogiri::XML("<mods #{@ns_decl}><titleInfo><title>#{title}</title></titleInfo></mods>")
        allow(@hdor_client).to receive(:mods).with(@fake_druid).and_return(ng_mods)
        expect_any_instance_of(Harvestdor::Indexer).to receive(:solr_add).with(hash_including(:title_display => title), @fake_druid)
        @indexer.index_item @fake_druid
      end
      it "should populate url_fulltext field with purl page url" do
        expect_any_instance_of(Harvestdor::Indexer).to receive(:solr_add).with(hash_including(:url_fulltext => "#{@yaml['purl']}/#{@fake_druid}"), @fake_druid)
        @indexer.index_item @fake_druid
      end
      it "should populate druid and access_facet fields" do
        expect_any_instance_of(Harvestdor::Indexer).to receive(:solr_add).with(hash_including(:druid => @fake_druid, :access_facet => 'Online'), @fake_druid)
        @indexer.index_item @fake_druid
      end
      it "should populate display_type field by calling display_type method" do
        expect_any_instance_of(GDor::Indexer::SolrDocBuilder).to receive(:display_type).and_return("foo")
        expect_any_instance_of(Harvestdor::Indexer).to receive(:solr_add).with(hash_including(:display_type => "foo"), @fake_druid)
        @indexer.index_item @fake_druid
      end
      it "should populate file_id field by calling file_ids method" do
        expect_any_instance_of(GDor::Indexer::SolrDocBuilder).to receive(:file_ids).at_least(1).times.and_return(["foo"])
        expect_any_instance_of(Harvestdor::Indexer).to receive(:solr_add).with(hash_including(:file_id => ["foo"]), @fake_druid)
        @indexer.index_item @fake_druid
      end
      it "should populate building_facet field with Stanford Digital Repository" do
        expect_any_instance_of(Harvestdor::Indexer).to receive(:solr_add).with(hash_including(:building_facet => 'Stanford Digital Repository'), @fake_druid)
        @indexer.index_item @fake_druid
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
        GDor::Indexer.config[:merge_policy] = nil
      end
      it "calls GDor::Indexer::RecordMerger.merge_and_index with gdor fields and item specific fields" do
        expect(GDor::Indexer::RecordMerger).to receive(:merge_and_index).with(@ickey, hash_including(:display_type => 'fiddle',
                                                                                  :file_id => ['dee', 'dum'],
                                                                                  :druid => @fake_druid,
                                                                                  :url_fulltext => "#{@yaml['purl']}/#{@fake_druid}",
                                                                                  :access_facet => 'Online',
                                                                                  :collection => ['foo'],
                                                                                  :collection_with_title => ['foo-|-bar'],
                                                                                  :building_facet => 'Stanford Digital Repository' ))
        @indexer.index_item @fake_druid
      end
      it "calls add_coll_info" do
        expect(@indexer).to receive(:add_coll_info).at_least(1).times
        expect(GDor::Indexer::RecordMerger).to receive(:merge_and_index)
        @indexer.index_item @fake_druid
      end
      it "calls validate_item" do
        expect_any_instance_of(GDor::Indexer::SolrDocHash).to receive(:validate_item).at_least(1).times.and_return([])
        expect(GDor::Indexer::RecordMerger).to receive(:merge_and_index)
        @indexer.index_item @fake_druid
      end
      it "should add a doc to Solr with item fields added" do
        expect_any_instance_of(SolrjWrapper).to receive(:add_doc_to_ix).with(hash_including('display_type', 'file_id', 'druid', 'collection', 'collection_with_title', 'building_facet'), @ickey)
        @indexer.index_item @fake_druid
      end
    end # merged item
  end # index_item 
  
  it "coll_druid_from_config gets the druid from the config" do
    expect_any_instance_of(String).to receive(:include?).with('is_member_of_collection_').and_call_original
    expect(@indexer.coll_druid_from_config).to eql(@coll_druid_from_test_config)
  end

  context "#index_coll_obj_per_config" do
    context "merge or not?" do
      it "uses GDor::Indexer::RecordMerger if there is a catkey" do
        ckey = '666'
        allow(@indexer).to receive(:coll_catkey).and_return(ckey)
        expect(GDor::Indexer::RecordMerger).to receive(:merge_and_index)
        @indexer.index_coll_obj_per_config
      end
      it "does not use GDor::Indexer::RecordMerger if there isn't a catkey" do
        allow(@indexer).to receive(:coll_catkey).and_return(nil)
        expect(GDor::Indexer::RecordMerger).not_to receive(:merge_and_index)
        allow_any_instance_of(GDor::Indexer::SolrDocBuilder).to receive(:doc_hash).and_return(GDor::Indexer::SolrDocHash.new) # speed up the test
        expect(@indexer.solr_client).to receive(:add)
        @indexer.index_coll_obj_per_config
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
          it "uses GDor::Indexer::RecordMerger if SW Solr index has record" do
            GDor::Indexer.config[:merge_policy] = policy
            expect(GDor::Indexer::RecordMerger).to receive(:merge_and_index).with(@ckey, instance_of(GDor::Indexer::SolrDocHash))
            @indexer.index_coll_obj_per_config
          end
          it "falls back to MODS with error message if no record in SW Solr index" do
            GDor::Indexer.config[:merge_policy] = policy
            expect(GDor::Indexer::RecordMerger).to receive(:fetch_sw_solr_input_doc).with(@ckey).and_return(nil)
            expect(GDor::Indexer::RecordMerger).to receive(:merge_and_index).with(@ckey, instance_of(GDor::Indexer::SolrDocHash)).and_call_original
            expect(@indexer.logger).to receive(:error).with("#{@coll_druid_from_test_config} to be indexed from MODS:  MARC record #{@ckey} not found in SW Solr index (may be shadowed in Symphony)")
            expect(@indexer.solr_client).to receive(:add)
            @indexer.index_coll_obj_per_config
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
            GDor::Indexer.config[:merge_policy] = policy
            expect(GDor::Indexer::RecordMerger).not_to receive(:merge_and_index)
            expect(@indexer.logger).not_to receive(:error)
            expect(@indexer.solr_client).to receive(:add)
            @indexer.index_coll_obj_per_config
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
        @indexer.index_coll_obj_per_config
      end
      it "calls validate_collection" do
        doc_hash = GDor::Indexer::SolrDocHash.new
        allow_any_instance_of(GDor::Indexer::SolrDocBuilder).to receive(:doc_hash).and_return(doc_hash) # speed up the test
        expect(doc_hash).to receive(:validate_collection)
        @indexer.index_coll_obj_per_config
      end
      it "calls GDor::Indexer::SolrDocBuilder.validate_mods" do
        doc_hash = GDor::Indexer::SolrDocHash.new
        allow_any_instance_of(GDor::Indexer::SolrDocBuilder).to receive(:doc_hash).and_return(doc_hash) # speed up the test
        expect(doc_hash).to receive(:validate_mods)
        @indexer.index_coll_obj_per_config
      end
      context "display_type" do
        it "includes display_types from coll_display_types_from_items when the druid matches" do
          allow(@indexer).to receive(:coll_display_types_from_items).and_return({@coll_druid_from_test_config => ['image']})
          allow_any_instance_of(GDor::Indexer::SolrDocBuilder).to receive(:doc_hash).and_return(GDor::Indexer::SolrDocHash.new)
          expect(@indexer.solr_client).to receive(:add).with(hash_including(:display_type => ['image']))
          @indexer.index_coll_obj_per_config
        end
        it "does not include display_types from coll_display_types_from_items when the druid doesn't match" do
          allow(@indexer).to receive(:coll_display_types_from_items).and_return({'foo' => ['image']})
          allow_any_instance_of(GDor::Indexer::SolrDocBuilder).to receive(:doc_hash).and_return(GDor::Indexer::SolrDocHash.new)
          expect(@indexer.solr_client).not_to receive(:add).with(hash_including(:display_type => ['image']))
          @indexer.index_coll_obj_per_config
        end
      end
      it "populates druid and access_facet fields" do
        expect_any_instance_of(Harvestdor::Indexer).to receive(:solr_add).with(hash_including(:druid => @coll_druid_from_test_config, 
                                                                                        :access_facet => 'Online'), 
                                                                                        @coll_druid_from_test_config)
        @indexer.index_coll_obj_per_config
      end
      it "populates url_fulltext field with purl page url" do
        expect_any_instance_of(Harvestdor::Indexer).to receive(:solr_add).with(hash_including(:url_fulltext => "#{@yaml['purl']}/#{@coll_druid_from_test_config}"), 
                                                                                        @coll_druid_from_test_config)
        @indexer.index_coll_obj_per_config
      end
      it "collection_type should be 'Digital Collection'" do
        allow_any_instance_of(GDor::Indexer::SolrDocBuilder).to receive(:doc_hash).and_return(GDor::Indexer::SolrDocHash.new) # speed up the test
        expect(@indexer.solr_client).to receive(:add).with(hash_including(:collection_type => 'Digital Collection'))
        @indexer.index_coll_obj_per_config
      end
      context "add format_main_ssim Archive/Manuscript" do
        it "no other values" do
          allow_any_instance_of(GDor::Indexer::SolrDocBuilder).to receive(:doc_hash).and_return(GDor::Indexer::SolrDocHash.new)
          expect(@indexer.solr_client).to receive(:add).with(hash_including(:format_main_ssim => 'Archive/Manuscript'))
          @indexer.index_coll_obj_per_config
        end
        it "other values present" do
          allow_any_instance_of(GDor::Indexer::SolrDocBuilder).to receive(:doc_hash).and_return(GDor::Indexer::SolrDocHash.new({:format_main_ssim => ['Image', 'Video']}))
          expect(@indexer.solr_client).to receive(:add).with(hash_including(:format_main_ssim => ['Image', 'Video', 'Archive/Manuscript']))
          @indexer.index_coll_obj_per_config
        end
        it "already has values Archive/Manuscript" do
          allow_any_instance_of(GDor::Indexer::SolrDocBuilder).to receive(:doc_hash).and_return(GDor::Indexer::SolrDocHash.new({:format_main_ssim => 'Archive/Manuscript'}))
          expect(@indexer.solr_client).to receive(:add).with(hash_including(:format_main_ssim => ['Archive/Manuscript']))
          @indexer.index_coll_obj_per_config
        end
      end
      it "populates building_facet field with Stanford Digital Repository" do
        expect_any_instance_of(Harvestdor::Indexer).to receive(:solr_add).with(hash_including(:building_facet => 'Stanford Digital Repository'), 
                                                                                        @coll_druid_from_test_config)
        @indexer.index_coll_obj_per_config
      end
    end # unmerged collection

    context "merged with marc" do
      before(:each) do
        @ckey = '666'
        allow(@indexer).to receive(:coll_catkey).and_return(@ckey)
      end
      it "should call GDor::Indexer::RecordMerger.merge_and_index with gdor fields and collection specific fields" do
        allow(@indexer).to receive(:coll_display_types_from_items).and_return({@coll_druid_from_test_config => ['image']})
        expect(GDor::Indexer::RecordMerger).to receive(:merge_and_index).with(@ckey, hash_including(:display_type => ['image'],
                                                                                :druid => @coll_druid_from_test_config,
                                                                                :url_fulltext => "#{@yaml['purl']}/#{@coll_druid_from_test_config}",
                                                                                :access_facet => 'Online', 
                                                                                :collection_type => "Digital Collection",
                                                                                :format_main_ssim => "Archive/Manuscript",
                                                                                :building_facet => 'Stanford Digital Repository'))
        @indexer.index_coll_obj_per_config
      end
      it "should call GDor::Indexer::RecordMerger.add_hash_to_solr_input_doc with gdor fields and collection specific fields" do
        allow(@indexer).to receive(:coll_display_types_from_items).and_return({@coll_druid_from_test_config => ['image']})
        allow(GDor::Indexer::RecordMerger).to receive(:merge_and_index).and_call_original
        expect(GDor::Indexer::RecordMerger).to receive(:add_hash_to_solr_input_doc).with(anything, 
                                                                          hash_including(:display_type => ['image'],
                                                                                :druid => @coll_druid_from_test_config,
                                                                                :url_fulltext => "#{@yaml['purl']}/#{@coll_druid_from_test_config}",
                                                                                :access_facet => 'Online', 
                                                                                :collection_type => "Digital Collection",
                                                                                :format_main_ssim => "Archive/Manuscript",
                                                                                :building_facet => 'Stanford Digital Repository'))
        @indexer.index_coll_obj_per_config
      end
      it "validates the collection doc via validate_collection" do
        expect_any_instance_of(GDor::Indexer::SolrDocHash).to receive(:validate_collection)
        @indexer.index_coll_obj_per_config
      end
      it "should add a doc to Solr with gdor fields and collection specific fields" do
        allow(@indexer).to receive(:coll_display_types_from_items).and_return({@coll_druid_from_test_config => ['image']})
        expect_any_instance_of(SolrjWrapper).to receive(:add_doc_to_ix).with(
                hash_including('druid', 'display_type', 'url_fulltext', 'access_facet', 'collection_type', 'format', 'building_facet'), @ckey)
        @indexer.index_coll_obj_per_config
      end
      context "add format_main_ssim Archive/Manuscript" do
        before(:each) do
          @solr_input_doc = GDor::Indexer::RecordMerger.fetch_sw_solr_input_doc @key
          allow(@indexer).to receive(:coll_display_types_from_items).and_return({@coll_druid_from_test_config => ['image']})
        end
        it "no other values" do
          expect_any_instance_of(SolrjWrapper).to receive(:add_doc_to_ix) do | sid_arg, ckey_arg |
            expect(sid_arg["format_main_ssim"].getValue).to eq('Archive/Manuscript')
          end
          @indexer.index_coll_obj_per_config
        end
        it "other values present" do
          expect_any_instance_of(SolrjWrapper).to receive(:add_doc_to_ix) do | sid_arg, ckey_arg |
            expect(sid_arg["format_main_ssim"].getValue).to match_array ['Image', 'Video', 'Archive/Manuscript']
          end
          @indexer.index_coll_obj_per_config
        end
        it "already has value Archive/Manuscript" do
          expect_any_instance_of(SolrjWrapper).to receive(:add_doc_to_ix) do | sid_arg, ckey_arg |
            expect(sid_arg["format_main_ssim"].getValue).to eq('Archive/Manuscript')
          end
          @indexer.index_coll_obj_per_config
        end
      end
    end # merged collection
  end #  index_coll_obj_per_config
  
  context "#add_coll_info and supporting methods" do
    before(:all) do
      @coll_druids_array = [@coll_druid_from_test_config]
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
        allow(@indexer).to receive(:identity_md_obj_label)
        doc_hash = GDor::Indexer::SolrDocHash.new({})
        @indexer.add_coll_info(doc_hash, [coll_druid1, coll_druid2])
        expect(doc_hash[:collection]).to match_array [coll_druid1, coll_druid2]
      end
      it "should have the ckey when the collection record is merged" do
        doc_hash = GDor::Indexer::SolrDocHash.new({})
        allow(@indexer).to receive(:coll_catkey).and_return('666')
        @indexer.add_coll_info(doc_hash, @coll_druids_array)
        expect(doc_hash[:collection]).to match_array ['666']
      end
      # other tests show it uses druid when coll rec isn't merged
    end

    context "collection_with_title field" do
      it "should be added to doc_hash" do
        coll_druid = 'oo000oo1234'
        expect(@indexer).to receive(:identity_md_obj_label).with(coll_druid).and_return('zzz')
        doc_hash = GDor::Indexer::SolrDocHash.new({})
        @indexer.add_coll_info(doc_hash, [coll_druid])
        expect(doc_hash[:collection_with_title]).to match_array ["#{coll_druid}-|-zzz"]
      end
      it "should add two values to doc_hash when object belongs to two collections" do
        coll_druid1 = 'oo111oo2222'
        coll_druid2 = 'oo333oo4444'
        expect(@indexer).to receive(:identity_md_obj_label).with(coll_druid1).and_return('foo')
        expect(@indexer).to receive(:identity_md_obj_label).with(coll_druid2).and_return('bar')
        doc_hash = GDor::Indexer::SolrDocHash.new({})
        @indexer.add_coll_info(doc_hash, [coll_druid1, coll_druid2])
        expect(doc_hash[:collection_with_title]).to match_array ["#{coll_druid1}-|-foo", "#{coll_druid2}-|-bar"]
      end
      it "should have the ckey when the collection record is merged" do
        coll_druid = 'aa000aa1234'
        expect(@indexer).to receive(:identity_md_obj_label).with(coll_druid).and_return('zzz')
        allow(@indexer).to receive(:coll_catkey).and_return('666')
        doc_hash = GDor::Indexer::SolrDocHash.new({})
        @indexer.add_coll_info(doc_hash, [coll_druid])
        expect(doc_hash[:collection_with_title]).to match_array ['666-|-zzz']
      end
      # other tests show it uses druid when coll rec isn't merged
    end
    
    context "coll_druid_2_title_hash interactions" do
      it "should add any missing druids" do
        allow(@indexer).to receive(:coll_druid_2_title_hash).and_return({})
        allow(@indexer).to receive(:identity_md_obj_label)
        @indexer.add_coll_info({}, @coll_druids_array)
        expect(@indexer.coll_druid_2_title_hash.keys).to eq(@coll_druids_array)
      end
      it "should retrieve missing collection titles via identity_md_obj_label" do
        allow(@indexer).to receive(:identity_md_obj_label).and_return('qqq')
        @indexer.add_coll_info({}, @coll_druids_array)
        expect(@indexer.coll_druid_2_title_hash[@coll_druid_from_test_config]).to eq('qqq')
      end
    end # coll_druid_2_title_hash

    context "#coll_display_types_from_items" do
      before(:each) do
        allow(@hdor_client).to receive(:public_xml).and_return(@ng_pub_xml)
        @indexer.coll_display_types_from_items[@coll_druid_from_test_config] = []
      end
      it "gets single item display_type for single collection (and no dups)" do
        allow(@indexer).to receive(:identity_md_obj_label)
        doc_hash = GDor::Indexer::SolrDocHash.new({:display_type => 'image'})
        @indexer.add_coll_info(doc_hash, @coll_druids_array)
        doc_hash = GDor::Indexer::SolrDocHash.new({:display_type => 'image'})
        @indexer.add_coll_info(doc_hash, @coll_druids_array)
        expect(@indexer.coll_display_types_from_items[@coll_druid_from_test_config]).to match_array ['image']
      end
      it "gets multiple formats from multiple items for single collection" do
        allow(@indexer).to receive(:identity_md_obj_label)
        doc_hash = GDor::Indexer::SolrDocHash.new({:display_type => 'image'})
        @indexer.add_coll_info(doc_hash, @coll_druids_array)
        doc_hash = GDor::Indexer::SolrDocHash.new({:display_type => 'file'})
        @indexer.add_coll_info(doc_hash, @coll_druids_array)
        expect(@indexer.coll_display_types_from_items[@coll_druid_from_test_config]).to match_array ['image', 'file']
      end
    end # coll_display_types_from_items
    it "#add_to_coll_display_types_from_item doesn't allow duplicate values" do
      indexer = GDor::Indexer.new(@config_yml_path, @client_config_path, @solr_yml_path)
      indexer.add_to_coll_display_types_from_item('foo', 'image')
      indexer.add_to_coll_display_types_from_item('foo', 'image')
      expect(indexer.coll_display_types_from_items['foo'].size).to eq(1)
    end
  end #add_coll_info

  context "#identity_md_obj_label" do
    before(:all) do
      @coll_title = "My Collection Has a Lovely Title"
      @ng_id_md_xml = Nokogiri::XML("<identityMetadata><objectLabel>#{@coll_title}</objectLabel></identityMetadata>")
    end
    before(:each) do
      allow(@hdor_client).to receive(:identity_metadata).with(@fake_druid).and_return(@ng_id_md_xml)
    end
    it "should retrieve the identityMetadata via the harvestdor client" do
      expect(@hdor_client).to receive(:identity_metadata).with(@fake_druid)
      @indexer.identity_md_obj_label(@fake_druid)
    end
    it "should get the value of the objectLabel element in the identityMetadata" do
      expect(@indexer.identity_md_obj_label(@fake_druid)).to eq(@coll_title)
    end
  end
  
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
      expect(@indexer.num_found_in_solr).to eq(266)
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
      expect(@indexer.num_found_in_solr).to eq(266)
    end
    it 'should verify the collection object has a purl' do
      allow(@indexer.solr_client).to receive(:get) do |wt, params|
        if params[:qt]
          @bad_collection_response
        else
          @item_response
        end
        expect(@indexer.num_found_in_solr).to eq(265)
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

  context "Integration with dor-fetcher-service" do
    it "has a local cache of item druids from the dor-fetcher-service" do
      expect(@indexer.druid_item_array).not_to be_nil
    end
    it "the druid array should not contain the collection level druid" do
      VCR.use_cassette('no_coll_druid_in_druid_array_call') do
        @indexer.populate_druid_item_array
        expect(@indexer.druid_item_array).not_to include "druid:#{@indexer.coll_druid_from_config}"
      end
    end
  end

  context "skip heartbeat" do
    it "allows me to use a fake url for dor-fetcher-client" do
      expect {GDor::Indexer.new(@config_yml_path, @client_config_path, @solr_yml_path)}.not_to raise_error
    end
  end

end
