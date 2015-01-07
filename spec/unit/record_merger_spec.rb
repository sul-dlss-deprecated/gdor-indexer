require 'spec_helper'

describe GDor::Indexer::RecordMerger do
  before(:all) do
    config_yml_path = File.join(File.dirname(__FILE__), "..", "config", "walters_integration_spec.yml")
    solr_yml_path = File.join(File.dirname(__FILE__), "..", "config", "solr.yml")
    client_config_path = File.join(File.dirname(__FILE__), "..", "config", "dor-fetcher-client.yml")
    @indexer = GDor::Indexer.new(config_yml_path, client_config_path, solr_yml_path)
    @catkey = '666'
  end
  before(:each) do
    @solr_input_doc = subject.fetch_sw_solr_input_doc @catkey
  end

  subject do
    GDor::Indexer::RecordMerger.new @indexer
  end

  context "#fetch_sw_solr_input_doc" do
    it "should return a java SolrInputDocument" do
      expect(@solr_input_doc.class).to eq(Java::OrgApacheSolrCommon::SolrInputDocument)
    end
    it "should have the ckey in the id field" do
      expect(@solr_input_doc.getField('id').getValue).to eq(@catkey)
    end
    it "should call SolrmarcWrapper.get_solr_input_doc_from_marcxml" do
      ckey = '123456'
      expect_any_instance_of(SolrmarcWrapper).to receive(:get_solr_input_doc_from_marcxml).with(ckey)
      subject.fetch_sw_solr_input_doc ckey
    end
  end
  
  context "#add_hash_to_solr_input_doc" do
    it "should add all fields in the hash to the solr_input_doc" do
      hash = {
        'a' => '1',
        'b' => '2',
        'c' => '3'
      }
      subject.add_hash_to_solr_input_doc(@solr_input_doc, hash)
      hash.each_pair { |name, val|  
        expect(@solr_input_doc.getField(name).getValue).to eq(val)
      }
    end
    it "should convert symbol field names into strings" do
      subject.add_hash_to_solr_input_doc(@solr_input_doc, {:a => 'val'})
      expect(@solr_input_doc.getField('a').getValue).to eq('val')
    end
    it "should add each value if the hash value is an Array" do
      subject.add_hash_to_solr_input_doc(@solr_input_doc, {:a => ['1', '2']})
      valCollection = @solr_input_doc.getField('a').getValues
      expect(valCollection.size).to eq(2)
      expect(valCollection.contains('1')).to eq(true)
      expect(valCollection.contains('2')).to eq(true)
    end
    it "should raise an error if a hash value isn't an Array or String" do
      expect { 
        subject.add_hash_to_solr_input_doc(@solr_input_doc, {:a => Hash.new}) 
      }.to raise_error(RuntimeError, /^hash to add to merged solr document has incorrectly typed field value for a: /)
    end
  end
  
  context "#merge_and_index" do
    before(:all) do
      @hash =  {'a' => '1', 'b' => '2'}
    end
    it "should call add_hash_to_solr_input_doc with hash passed in to merge_and_index" do
      expect(subject).to receive(:add_hash_to_solr_input_doc).with(anything, @hash)
      expect_any_instance_of(SolrjWrapper).to receive(:add_doc_to_ix)
      subject.merge_and_index(@catkey, @hash)
    end
    it "should call SolrjWrapper.add_doc_to_index with fields from the passed hash" do
      expect_any_instance_of(SolrjWrapper).to receive(:add_doc_to_ix).with(hash_including('a', 'b'), @catkey)
      subject.merge_and_index(@catkey, @hash)
    end
  end
end