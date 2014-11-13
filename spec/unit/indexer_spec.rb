require 'spec_helper'
require 'rsolr'
require 'record_merger'

describe Indexer do
  
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
    @indexer = Indexer.new(@config_yml_path, @client_config_path, @solr_yml_path)
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
      @indexer.stub(:num_found_in_solr)
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
      Harvestdor::Indexer.any_instance.should_receive(:druids).at_least(1).times.and_return(['1', '2', '3'])
      @indexer.should_receive(:index_item).with('1')
      @indexer.should_receive(:index_item).with('2')
      @indexer.should_receive(:index_item).with('3')
      @indexer.harvest_and_index(true) # nocommit for ease of testing
    end
    it "should call index_coll_obj_per_config once for the coll druid from the config file" do
      Harvestdor::Indexer.any_instance.should_receive(:druids).at_least(1).times.and_return([])
      @indexer.should_receive(:index_coll_obj_per_config)
      @indexer.harvest_and_index(true) # nocommit for ease of testing
    end
  end # harvest_and_index
  
  context "#index_item" do

    context "merge or not?" do
      it "uses RecordMerger if there is a catkey" do
        ckey = '666'
        sdb = double
        sdb.stub(:catkey).and_return(ckey)
        sdb.stub(:doc_hash).and_return({})
        sdb.stub(:coll_druids_from_rels_ext)
        sdb.stub(:public_xml)
        sdb.stub(:display_type)
        sdb.stub(:file_ids)
        sdb.stub(:validate_mods).and_return([])
        SolrDocBuilder.stub(:new).and_return(sdb)
        RecordMerger.should_receive(:merge_and_index).with(ckey, instance_of(Hash))
        @indexer.index_item @fake_druid
      end
      it "does not use RecordMerger if there isn't a catkey" do
        sdb = double
        sdb.stub(:catkey).and_return(nil)
        sdb.stub(:public_xml)
        sdb.stub(:doc_hash).and_return({})
        sdb.stub(:coll_druids_from_rels_ext)
        sdb.stub(:display_type)
        sdb.stub(:file_ids)
        sdb.stub(:validate_mods).and_return([])
        SolrDocBuilder.stub(:new).and_return(sdb)
        RecordMerger.should_not_receive(:merge_and_index)
        @indexer.solr_client.should_receive(:add)
        @indexer.index_item @fake_druid
      end
      context "config.merge_policy" do
        before(:each) do
          @sdb = double
          @sdb.stub(:coll_druids_from_rels_ext)
          @sdb.stub(:public_xml)
          @sdb.stub(:display_type)
          @sdb.stub(:file_ids)
          # for unmerged items only
          @sdb.stub(:doc_hash).and_return({})
          @sdb.stub(:validate_mods).and_return([])
        end
        context "have catkey" do
          before(:each) do
            @ckey = '666'
            @sdb.stub(:catkey).and_return(@ckey)
            SolrDocBuilder.stub(:new).and_return(@sdb)
          end
          context "merge_policy 'always'" do
            it "uses RecordMerger if SW Solr index has record" do
              Indexer.config[:merge_policy] = 'always'
              RecordMerger.should_receive(:merge_and_index).with(@ckey, instance_of(Hash))
              @indexer.index_item @fake_druid
            end
            it "fails with error message if no record in SW Solr index" do
              Indexer.config[:merge_policy] = 'always'
              RecordMerger.should_receive(:fetch_sw_solr_input_doc).with(@ckey).and_return(nil)
              RecordMerger.should_receive(:merge_and_index).with(@ckey, instance_of(Hash)).and_call_original
              @indexer.logger.should_receive(:error).with("#{@fake_druid} NOT INDEXED:  MARC record #{@ckey} not found in SW Solr index (may be shadowed in Symphony) and merge_policy set to 'always'")
              @indexer.solr_client.should_not_receive(:add)
              @indexer.index_item @fake_druid
            end
          end
          context "merge_policy 'never'" do
            it "does not use RecordMerger and prints warning message" do
              Indexer.config[:merge_policy] = 'never'
              RecordMerger.should_not_receive(:merge_and_index)
              @indexer.logger.should_receive(:warn).with("#{@fake_druid} to be indexed from MODS; has ckey #{@ckey} but merge_policy is 'never'")
              @indexer.solr_client.should_receive(:add)
              @indexer.index_item @fake_druid
            end
          end
          context "merge_policy not set" do
            it "uses RecordMerger if SW Solr index has record" do
              Indexer.config[:merge_policy] = nil
              RecordMerger.should_receive(:merge_and_index).with(@ckey, instance_of(Hash))
              @indexer.index_item @fake_druid
            end
            it "falls back to MODS with error message if no record in SW Solr index" do
              Indexer.config[:merge_policy] = nil
              RecordMerger.stub(:fetch_sw_solr_input_doc).with(@ckey).and_return(nil)
              RecordMerger.should_receive(:merge_and_index).with(@ckey, instance_of(Hash)).and_call_original
              @indexer.logger.should_receive(:error).with("#{@fake_druid} to be indexed from MODS:  MARC record #{@ckey} not found in SW Solr index (may be shadowed in Symphony)")
              @indexer.solr_client.should_receive(:add)
              @indexer.index_item @fake_druid
            end
          end
        end # have catkey
        context "no catkey" do
          before(:each) do
            @sdb.stub(:catkey).and_return(nil)
            SolrDocBuilder.stub(:new).and_return(@sdb)
          end
          it "merge_policy 'always' doesn't use the MODS and prints error message" do
            Indexer.config[:merge_policy] = 'always'
            RecordMerger.should_not_receive(:merge_and_index)
            @indexer.logger.should_receive(:error).with("#{@fake_druid} NOT INDEXED:  no ckey found and merge_policy set to 'always'")
            @indexer.solr_client.should_not_receive(:add)
            @indexer.index_item @fake_druid
          end
          it "merge_policy 'never' uses the MODS without error message" do
            Indexer.config[:merge_policy] = 'never'
            RecordMerger.should_not_receive(:merge_and_index)
            @indexer.logger.should_not_receive(:error)
            @indexer.solr_client.should_receive(:add)
            @indexer.index_item @fake_druid
          end
          it "merge_policy not set uses the MODS without error message" do
            RecordMerger.should_not_receive(:merge_and_index)
            @indexer.logger.should_not_receive(:error)
            @indexer.solr_client.should_receive(:add)
            @indexer.index_item @fake_druid
          end
        end # no catkey
      end # config.merge_policy
    end # merge or not?

    context "unmerged" do
      before(:each) do
        @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_xml)
      end
      it "calls Harvestdor::Indexer.solr_add" do
        Harvestdor::Indexer.any_instance.should_receive(:solr_add).with(instance_of(Hash), @fake_druid)
        @indexer.index_item @fake_druid
      end
      it "calls validate_item" do
        @indexer.should_receive(:validate_item)
        @indexer.index_item @fake_druid
      end
      it "calls SolrDocBuilder.validate_mods" do
        SolrDocBuilder.any_instance.should_receive(:validate_mods)
        @indexer.index_item @fake_druid
      end
      it "calls add_coll_info" do
        @indexer.should_receive(:add_coll_info)
        @indexer.index_item @fake_druid
      end
      it "should have fields populated from the collection record" do
        sdb = double
        sdb.stub(:catkey).and_return(nil)
        sdb.stub(:doc_hash).and_return({})
        sdb.stub(:display_type)
        sdb.stub(:file_ids)
        sdb.stub(:validate_mods).and_return([])
        SolrDocBuilder.stub(:new).and_return(sdb)
        sdb.stub(:coll_druids_from_rels_ext).and_return(['foo'])
        @indexer.stub(:identity_md_obj_label).with('foo').and_return('bar')
        Harvestdor::Indexer.any_instance.should_receive(:solr_add).with(hash_including(:collection => ['foo'], 
                                                                                        :collection_with_title => ['foo-|-bar']), @fake_druid)
        @indexer.index_item @fake_druid
      end
      it "should have fields populated from the MODS" do
        title = 'fake title in mods'
        ng_mods = Nokogiri::XML("<mods #{@ns_decl}><titleInfo><title>#{title}</title></titleInfo></mods>")
        @hdor_client.stub(:mods).with(@fake_druid).and_return(ng_mods)
        Harvestdor::Indexer.any_instance.should_receive(:solr_add).with(hash_including(:title_display => title), @fake_druid)
        @indexer.index_item @fake_druid
      end
      it "should populate url_fulltext field with purl page url" do
        Harvestdor::Indexer.any_instance.should_receive(:solr_add).with(hash_including(:url_fulltext => "#{@yaml['purl']}/#{@fake_druid}"), @fake_druid)
        @indexer.index_item @fake_druid
      end
      it "should populate druid and access_facet fields" do
        Harvestdor::Indexer.any_instance.should_receive(:solr_add).with(hash_including(:druid => @fake_druid, :access_facet => 'Online'), @fake_druid)
        @indexer.index_item @fake_druid
      end
      it "should populate display_type field by calling display_type method" do
        SolrDocBuilder.any_instance.should_receive(:display_type).and_return("foo")
        Harvestdor::Indexer.any_instance.should_receive(:solr_add).with(hash_including(:display_type => "foo"), @fake_druid)
        @indexer.index_item @fake_druid
      end
      it "should populate file_id field by calling file_ids method" do
        SolrDocBuilder.any_instance.should_receive(:file_ids).at_least(1).times.and_return(["foo"])
        Harvestdor::Indexer.any_instance.should_receive(:solr_add).with(hash_including(:file_id => ["foo"]), @fake_druid)
        @indexer.index_item @fake_druid
      end
      it "should populate building_facet field with Stanford Digital Repository" do
        Harvestdor::Indexer.any_instance.should_receive(:solr_add).with(hash_including(:building_facet => 'Stanford Digital Repository'), @fake_druid)
        @indexer.index_item @fake_druid
      end
    end # unmerged item

    context "merged with marc" do
      before(:each) do
        @ickey = '999'
        @sdb = double
        @sdb.stub(:catkey).and_return(@ickey)
        @sdb.stub(:coll_druids_from_rels_ext).and_return(['foo'])
        @sdb.stub(:doc_hash).and_return({})
        @sdb.stub(:display_type).and_return('fiddle')
        @sdb.stub(:file_ids).and_return(['dee', 'dum'])
        @sdb.stub(:validate_mods).and_return([])
        SolrDocBuilder.stub(:new).and_return(@sdb)
        @indexer.stub(:identity_md_obj_label).with('foo').and_return('bar')
        @indexer.stub(:coll_catkey).and_return(nil)
        Indexer.config[:merge_policy] = nil
      end
      it "calls RecordMerger.merge_and_index with gdor fields and item specific fields" do
        RecordMerger.should_receive(:merge_and_index).with(@ickey, hash_including(:display_type => 'fiddle',
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
        @indexer.should_receive(:add_coll_info)
        @indexer.index_item @fake_druid
      end
      it "calls validate_item" do
        @indexer.should_receive(:validate_item)
        @indexer.index_item @fake_druid
      end
      it "should add a doc to Solr with item fields added" do
        SolrjWrapper.any_instance.should_receive(:add_doc_to_ix).with(hash_including('display_type', 'file_id', 'druid', 'collection', 'collection_with_title', 'building_facet'), @ickey)
        @indexer.index_item @fake_druid
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
      before(:each) do
        @sdb = double
        @sdb.stub(:coll_druids_from_rels_ext)
        @sdb.stub(:public_xml)
        @sdb.stub(:display_type)
        @sdb.stub(:file_ids)
        # for unmerged items only
        @sdb.stub(:doc_hash).and_return({})
        @sdb.stub(:validate_mods).and_return([])
      end
      context "have catkey" do
        before(:each) do
          @ckey = '666'
          @sdb.stub(:catkey).and_return(@ckey)
          SolrDocBuilder.stub(:new).and_return(@sdb)
        end
        shared_examples_for 'uses MARC if it can find it' do | policy |
          it "uses RecordMerger if SW Solr index has record" do
            Indexer.config[:merge_policy] = policy
            RecordMerger.should_receive(:merge_and_index).with(@ckey, instance_of(Hash))
            @indexer.index_coll_obj_per_config
          end
          it "falls back to MODS with error message if no record in SW Solr index" do
            Indexer.config[:merge_policy] = policy
            RecordMerger.should_receive(:fetch_sw_solr_input_doc).with(@ckey).and_return(nil)
            RecordMerger.should_receive(:merge_and_index).with(@ckey, instance_of(Hash)).and_call_original
            @indexer.logger.should_receive(:error).with("#{@coll_druid_from_test_config} to be indexed from MODS:  MARC record #{@ckey} not found in SW Solr index (may be shadowed in Symphony)")
            @indexer.solr_client.should_receive(:add)
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
          @sdb.stub(:catkey).and_return(nil)
          SolrDocBuilder.stub(:new).and_return(@sdb)
        end
        shared_examples_for 'uses the MODS without error message' do | policy |
          it "" do
            Indexer.config[:merge_policy] = policy
            RecordMerger.should_not_receive(:merge_and_index)
            @indexer.logger.should_not_receive(:error)
            @indexer.solr_client.should_receive(:add)
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
      it "adds the collection doc to the index" do
        SolrDocBuilder.any_instance.stub(:doc_hash).and_return({}) # speed up the test
        @indexer.solr_client.should_receive(:add)
        @indexer.index_coll_obj_per_config
      end
      it "calls validate_collection" do
        SolrDocBuilder.any_instance.stub(:doc_hash).and_return({}) # speed up the test
        @indexer.should_receive(:validate_collection)
        @indexer.index_coll_obj_per_config
      end
      it "calls SolrDocBuilder.validate_mods" do
        SolrDocBuilder.any_instance.stub(:doc_hash).and_return({}) # speed up the test
        SolrDocBuilder.any_instance.should_receive(:validate_mods)
        @indexer.index_coll_obj_per_config
      end
      context "display_type" do
        it "includes display_types from coll_display_types_from_items when the druid matches" do
          @indexer.stub(:coll_display_types_from_items).and_return({@coll_druid_from_test_config => ['image']})
          SolrDocBuilder.any_instance.stub(:doc_hash).and_return({})
          @indexer.solr_client.should_receive(:add).with(hash_including(:display_type => ['image']))
          @indexer.index_coll_obj_per_config
        end
        it "does not include display_types from coll_display_types_from_items when the druid doesn't match" do
          @indexer.stub(:coll_display_types_from_items).and_return({'foo' => ['image']})
          SolrDocBuilder.any_instance.stub(:doc_hash).and_return({})
          @indexer.solr_client.should_not_receive(:add).with(hash_including(:display_type => ['image']))
          @indexer.index_coll_obj_per_config
        end
      end
      it "populates druid and access_facet fields" do
        Harvestdor::Indexer.any_instance.should_receive(:solr_add).with(hash_including(:druid => @coll_druid_from_test_config, 
                                                                                        :access_facet => 'Online'), 
                                                                                        @coll_druid_from_test_config)
        @indexer.index_coll_obj_per_config
      end
      it "populates url_fulltext field with purl page url" do
        Harvestdor::Indexer.any_instance.should_receive(:solr_add).with(hash_including(:url_fulltext => "#{@yaml['purl']}/#{@coll_druid_from_test_config}"), 
                                                                                        @coll_druid_from_test_config)
        @indexer.index_coll_obj_per_config
      end
      it "collection_type should be 'Digital Collection'" do
        SolrDocBuilder.any_instance.stub(:doc_hash).and_return({}) # speed up the test
        @indexer.solr_client.should_receive(:add).with(hash_including(:collection_type => 'Digital Collection'))
        @indexer.index_coll_obj_per_config
      end
      context "add format_main_ssim Archive/Manuscript" do
        it "no other values" do
          allow_any_instance_of(SolrDocBuilder).to receive(:doc_hash).and_return({})
          expect(@indexer.solr_client).to receive(:add).with(hash_including(:format_main_ssim => 'Archive/Manuscript'))
          @indexer.index_coll_obj_per_config
        end
        it "other values present" do
          allow_any_instance_of(SolrDocBuilder).to receive(:doc_hash).and_return({:format_main_ssim => ['Image', 'Video']})
          expect(@indexer.solr_client).to receive(:add).with(hash_including(:format_main_ssim => ['Image', 'Video', 'Archive/Manuscript']))
          @indexer.index_coll_obj_per_config
        end
        it "already has values Archive/Manuscript" do
          allow_any_instance_of(SolrDocBuilder).to receive(:doc_hash).and_return({:format_main_ssim => 'Archive/Manuscript'})
          expect(@indexer.solr_client).to receive(:add).with(hash_including(:format_main_ssim => ['Archive/Manuscript']))
          @indexer.index_coll_obj_per_config
        end
      end
      it "populates building_facet field with Stanford Digital Repository" do
        Harvestdor::Indexer.any_instance.should_receive(:solr_add).with(hash_including(:building_facet => 'Stanford Digital Repository'), 
                                                                                        @coll_druid_from_test_config)
        @indexer.index_coll_obj_per_config
      end
    end # unmerged collection

    context "merged with marc" do
      before(:each) do
        @ckey = '666'
        @indexer.stub(:coll_catkey).and_return(@ckey)
      end
      it "should call RecordMerger.merge_and_index with gdor fields and collection specific fields" do
        @indexer.stub(:coll_display_types_from_items).and_return({@coll_druid_from_test_config => ['image']})
        expect(RecordMerger).to receive(:merge_and_index).with(@ckey, hash_including(:display_type => ['image'],
                                                                                :druid => @coll_druid_from_test_config,
                                                                                :url_fulltext => "#{@yaml['purl']}/#{@coll_druid_from_test_config}",
                                                                                :access_facet => 'Online', 
                                                                                :collection_type => "Digital Collection",
                                                                                :format_main_ssim => "Archive/Manuscript",
                                                                                :building_facet => 'Stanford Digital Repository'))
        @indexer.index_coll_obj_per_config
      end
      it "should call RecordMerger.add_hash_to_solr_input_doc with gdor fields and collection specific fields" do
        @indexer.stub(:coll_display_types_from_items).and_return({@coll_druid_from_test_config => ['image']})
        allow(RecordMerger).to receive(:merge_and_index).and_call_original
        expect(RecordMerger).to receive(:add_hash_to_solr_input_doc).with(anything, 
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
        SolrDocBuilder.any_instance.stub(:doc_hash).and_return({}) # speed up the test
        expect(@indexer).to receive(:validate_collection)
        @indexer.index_coll_obj_per_config
      end
      it "should add a doc to Solr with gdor fields and collection specific fields" do
        @indexer.stub(:coll_display_types_from_items).and_return({@coll_druid_from_test_config => ['image']})
        expect_any_instance_of(SolrjWrapper).to receive(:add_doc_to_ix).with(
                hash_including('druid', 'display_type', 'url_fulltext', 'access_facet', 'collection_type', 'format', 'building_facet'), @ckey)
        @indexer.index_coll_obj_per_config
      end
      context "add format_main_ssim Archive/Manuscript" do
        before(:each) do
          @solr_input_doc = RecordMerger.fetch_sw_solr_input_doc @key
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
            expect(sid_arg["format_main_ssim"].getValue).to eq(['Image', 'Video', 'Archive/Manuscript'])
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
      doc_hash = {}
      @indexer.add_coll_info(doc_hash, nil)
      doc_hash[:collection].should == nil
      doc_hash[:collection_with_title].should == nil
      doc_hash[:display_type].should == nil
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
      it "should have the ckey when the collection record is merged" do
        doc_hash = {}
        @indexer.stub(:coll_catkey).and_return('666')
        @indexer.add_coll_info(doc_hash, @coll_druids_array)
        doc_hash[:collection].should == ['666']
      end
      # other tests show it uses druid when coll rec isn't merged
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
      it "should have the ckey when the collection record is merged" do
        coll_druid = 'aa000aa1234'
        @indexer.should_receive(:identity_md_obj_label).with(coll_druid).and_return('zzz')
        @indexer.stub(:coll_catkey).and_return('666')
        doc_hash = {}
        @indexer.add_coll_info(doc_hash, [coll_druid])
        doc_hash[:collection_with_title].should == ['666-|-zzz']
      end
      # other tests show it uses druid when coll rec isn't merged
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

    context "#coll_display_types_from_items" do
      before(:each) do
        @hdor_client.stub(:public_xml).and_return(@ng_pub_xml)
        @indexer.coll_display_types_from_items[@coll_druid_from_test_config] = []
      end
      it "gets single item display_type for single collection (and no dups)" do
        @indexer.stub(:identity_md_obj_label)
        doc_hash = {:display_type => 'image'}
        @indexer.add_coll_info(doc_hash, @coll_druids_array)
        doc_hash = {:display_type => 'image'}
        @indexer.add_coll_info(doc_hash, @coll_druids_array)
        @indexer.coll_display_types_from_items[@coll_druid_from_test_config].should == ['image']
      end
      it "gets multiple formats from multiple items for single collection" do
        @indexer.stub(:identity_md_obj_label)
        doc_hash = {:display_type => 'image'}
        @indexer.add_coll_info(doc_hash, @coll_druids_array)
        doc_hash = {:display_type => 'file'}
        @indexer.add_coll_info(doc_hash, @coll_druids_array)
        @indexer.coll_display_types_from_items[@coll_druid_from_test_config].should == ['image', 'file']
      end
    end # coll_display_types_from_items
    it "#add_to_coll_display_types_from_item doesn't allow duplicate values" do
      indexer = Indexer.new(@config_yml_path, @client_config_path, @solr_yml_path)
      indexer.add_to_coll_display_types_from_item('foo', 'image')
      indexer.add_to_coll_display_types_from_item('foo', 'image')
      indexer.coll_display_types_from_items['foo'].size.should == 1
    end
  end #add_coll_info

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
  
  context "#num_found_in_solr" do
    before :each do 
      @unmerged_collection_response = {'response' => {'numFound'=>'1','docs'=>[{'id'=>'dm212rn7381', 'url_fulltext' => ['http://purl.stanford.edu/dm212rn7381']}]}}
      @merged_collection_response = {'response' => {'numFound'=>'1','docs'=>[{'id'=>'666', 'url_fulltext' => ['http://purl.stanford.edu/dm212rn7381']}]}}
      @bad_collection_response = {'response' => {'numFound'=>'1','docs'=>[{'id'=>'dm212rn7381'}]}}
      @item_response = {'response' => {'numFound'=>'265','docs'=>[{'id'=>'dm212rn7381'}]}}
    end

    it 'should count the items and the collection object in the solr index after indexing (merged)' do
      @indexer.stub(:coll_catkey).and_return("666")
      @indexer.stub(:coll_druid_from_config).and_return('dm212rn7381')
      @indexer.solr_client.stub(:get) do |wt, params|
        if params[:params][:fl].include?('url_fulltext')
          @merged_collection_response
        else
          @item_response
        end
      end
      @indexer.num_found_in_solr.should == 266
    end
    it 'should count the items and the collection object in the solr index after indexing (unmerged)' do
      @indexer.stub(:coll_catkey).and_return(nil)
      @indexer.stub(:coll_druid_from_config).and_return('dm212rn7381')
      @indexer.solr_client.stub(:get) do |wt, params|
        if params[:params][:fl].include?('url_fulltext')
          @unmerged_collection_response
        else
          @item_response
        end
      end
      @indexer.num_found_in_solr.should == 266
    end
    it 'should verify the collection object has a purl' do
      @indexer.solr_client.stub(:get) do |wt, params|
        if params[:qt]
          @bad_collection_response
        else
          @item_response
        end
        @indexer.num_found_in_solr.should == 265
      end
    end
  end # num_found_in_solr

  context "#validate_gdor_fields" do
    it "should return an empty Array when there are no problems" do
      hash = {
        :access_facet => 'Online',
        :druid => @fake_druid,
        :url_fulltext => "#{@yaml['purl']}/#{@fake_druid}",
        :display_type => 'image',
        :building_facet => 'Stanford Digital Repository'}
      @indexer.validate_gdor_fields(@fake_druid, hash).should == []
    end
    it "should have a value for each missing field" do
      @indexer.validate_gdor_fields(@fake_druid, {}).length.should == 5
    end
    it "should have a value for an unrecognized display_type" do
      hash = {
        :access_facet => 'Online',
        :druid => @fake_druid,
        :url_fulltext => "#{@yaml['purl']}/#{@fake_druid}",
        :display_type => 'zzzz', 
        :building_facet => 'Stanford Digital Repository'}
      @indexer.validate_gdor_fields(@fake_druid, hash).first.should =~ /display_type/
    end
    it "should have a value for access_facet other than 'Online'" do
      hash = {
        :access_facet => 'BAD',
        :druid => @fake_druid,
        :url_fulltext => "#{@yaml['purl']}/#{@fake_druid}",
        :display_type => 'image', 
        :building_facet => 'Stanford Digital Repository'}
        @indexer.validate_gdor_fields(@fake_druid, hash).first.should =~ /access_facet/
    end
    it "should have a value for building_facet other than 'Stanford Digital Repository'" do
      hash = {
        :access_facet => 'Online',
        :druid => @fake_druid,
        :url_fulltext => "#{@yaml['purl']}/#{@fake_druid}",
        :display_type => 'image',
        :building_facet => 'WRONG'}
        @indexer.validate_gdor_fields(@fake_druid, hash).first.should =~ /building_facet/
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
        :file_id => ['anything']
      }
      @indexer.validate_item(@fake_druid, hash).first.should =~ /collection /
    end
    it "should have a value if collection_with_title is missing" do
      hash = {
        :collection => @coll_druid_from_test_config,
        :collection_with_title => nil,
        :file_id => ['anything']
      }
      @indexer.validate_item(@fake_druid, hash).first.should =~ /collection_with_title /
    end
    it "should have a value if collection_with_title is missing the title" do
      hash = {
        :collection => @coll_druid_from_test_config,
        :collection_with_title => "#{@coll_druid_from_test_config}-|-",
        :file_id => ['anything']
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
        :file_id => ['anything']
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
      @indexer.validate_collection(@fake_druid, {:format_main_ssim => 'Archive/Manuscript'}).first.should =~ /collection_type/
    end
    it "should have a value if collection_type is not 'Digital Collection'" do
      @indexer.validate_collection(@fake_druid, {:collection_type => 'lalalalala', :format_main_ssim => 'Archive/Manuscript'}).first.should =~ /collection_type/
    end
    it "should have a value if format_main_ssim is missing" do
      @indexer.validate_collection(@fake_druid, {:collection_type => 'Digital Collection'}).first.should =~ /format_main_ssim/
    end
    it "should have a value if format_main_ssim doesn't include 'Archive/Manuscript'" do
      @indexer.validate_collection(@fake_druid, {:format_main_ssim => 'lalalalala', :collection_type => 'Digital Collection'}).first.should =~ /format_main_ssim/
    end
    it "should not have a value if gdor_fields, collection_type and format_main_ssim are ok" do
      @indexer.validate_collection(@fake_druid, {:collection_type => 'Digital Collection', :format_main_ssim => 'Archive/Manuscript'}).should == []
    end
  end # validate_collection

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
        expect(hash[:body]).to match /Solr query for items: http:\/\/solr.baseurl.org\/select?fq=collection:ww121ss5000&fl=id,title_245a_display/
      end
      @indexer.send(:email_results)
    end
    it "email body includes failed to index druids" do
      @indexer.instance_variable_set(:@druids_failed_to_ix, ['a', 'b'])
      expect(@indexer).to receive(:send_email) do | email, hash |
        expect(hash[:body]).to match /records that may have failed to index (merged recs as druids, not ckeys): \na\nb\n\n/
      end
      @indexer.send(:email_results)
    end
    it "email includes reference to full log" do
      expect(@indexer).to receive(:send_email) do | email, hash |
        expect(hash[:body]).to match /full log is at gdor_indexer\/shared\/spec\/test_logs\/testcoll.log on harvestdor-specs/
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
        expect(@indexer.druid_item_array.include? "druid:#{@indexer.coll_druid_from_config}").to eq(false)
      end
    end
  end
end
