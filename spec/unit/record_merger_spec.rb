require 'spec_helper'
require 'record_merger'

describe RecordMerger do
  before(:all) do
    config_yml_path = File.join(File.dirname(__FILE__), "..", "config", "walters_integration_spec.yml")
    @solr_yml_path = File.join(File.dirname(__FILE__), "..", "config", "solr.yml")
    @indexer = Indexer.new(config_yml_path, @solr_yml_path)
    @catkey = '666'
  end
  before(:each) do
    @solr_input_doc = RecordMerger.fetch_sw_solr_input_doc @catkey
  end

  context "#fetch_sw_solr_input_doc" do
    it "should return a java SolrInputDocument" do
      @solr_input_doc.class.should == Java::OrgApacheSolrCommon::SolrInputDocument
    end
    it "should have the ckey in the id field" do
      @solr_input_doc.getField('id').getValue.should == @catkey
    end
    it "should call SolrmarcWrapper.get_solr_input_doc_from_marcxml" do
      ckey = '123456'
      SolrmarcWrapper.any_instance.should_receive(:get_solr_input_doc_from_marcxml).with(ckey)
      RecordMerger.fetch_sw_solr_input_doc ckey
    end
  end
  
  context "#add_hash_to_solr_input_doc" do
    it "should add all fields in the hash to the solr_input_doc" do
      hash = {
        'a' => '1',
        'b' => '2',
        'c' => '3'
      }
      RecordMerger.add_hash_to_solr_input_doc(@solr_input_doc, hash)
      hash.each_pair { |name, val|  
        @solr_input_doc.getField(name).getValue.should == val
      }
    end
    it "should convert symbol field names into strings" do
      RecordMerger.add_hash_to_solr_input_doc(@solr_input_doc, {:a => 'val'})
      @solr_input_doc.getField('a').getValue.should == 'val'
    end
    it "should add each value if the hash value is an Array" do
      RecordMerger.add_hash_to_solr_input_doc(@solr_input_doc, {:a => ['1', '2']})
      valCollection = @solr_input_doc.getField('a').getValues
      valCollection.size.should == 2
      valCollection.contains('1').should == true
      valCollection.contains('2').should == true
    end
    it "should raise an error if a hash value isn't an Array or String" do
      expect { 
        RecordMerger.add_hash_to_solr_input_doc(@solr_input_doc, {:a => Hash.new}) 
      }.to raise_error(RuntimeError, /^hash to add to merged solr document has incorrectly typed field value for a: /)
    end
  end
  
  context "#merge_and_index" do
    before(:all) do
      @hash =  {'a' => '1', 'b' => '2'}
    end
    it "should call add_hash_to_solr_input_doc with hash passed in to merge_and_index" do
      RecordMerger.should_receive(:add_hash_to_solr_input_doc).with(anything, @hash)
      SolrjWrapper.any_instance.should_receive(:add_doc_to_ix)
      RecordMerger.merge_and_index(@catkey, @hash)
    end
    it "should call SolrjWrapper.add_doc_to_index with fields from the passed hash" do
      SolrjWrapper.any_instance.should_receive(:add_doc_to_ix).with(hash_including('a', 'b'), @catkey)
      RecordMerger.merge_and_index(@catkey, @hash)
    end
  end
end