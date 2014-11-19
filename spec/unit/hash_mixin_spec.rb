require 'spec_helper'

describe GDor::Indexer::SolrDocHash do
  context "#field_present?" do
    
    context "actual field value is boolean true" do
      it "true if expected value is nil" do
        GDor::Indexer::SolrDocHash.new({:a => true}).field_present?(:a).should == false
      end
      it "false if expected value is String" do
        GDor::Indexer::SolrDocHash.new({:a => true}).field_present?(:a, 'true').should == false
      end
      it "false if expected value is Regex" do
        GDor::Indexer::SolrDocHash.new({:a => true}).field_present?(:a => /true/).should == false
      end
    end

    context "expected value is nil" do
      it "false if the field is not in the doc_hash" do
        GDor::Indexer::SolrDocHash.new({}).field_present?(:any).should == false
      end
      it "false if hash[field] is nil" do
        GDor::Indexer::SolrDocHash.new({:foo => nil}).field_present?(:foo).should == false
      end
      it "false if hash[field] is an empty String" do
        GDor::Indexer::SolrDocHash.new({:foo => ""}).field_present?(:foo).should == false
      end
      it "true if hash[field] is a non-empty String" do
        GDor::Indexer::SolrDocHash.new({:foo => 'bar'}).field_present?(:foo).should == true
      end
      it "false if hash[field] is an empty Array" do
        GDor::Indexer::SolrDocHash.new({:foo => []}).field_present?(:foo).should == false
      end
      it "false if hash[field] is an Array with only empty String values" do
        GDor::Indexer::SolrDocHash.new({:foo => ["", ""]}).field_present?(:foo).should == false
      end
      it "false if hash[field] is an Array with only nil String values" do
        GDor::Indexer::SolrDocHash.new({:foo => [nil]}).field_present?(:foo).should == false
      end
      it "true if hash[field] is a non-empty Array" do
        GDor::Indexer::SolrDocHash.new({:foo => ["a"]}).field_present?(:foo).should == true
      end
      it "false if doc_hash[field] is not a String or Array" do
        GDor::Indexer::SolrDocHash.new({:foo => {}}).field_present?(:foo).should == false
      end
    end
    
    context "expected value is a String" do
      it "true if hash[field] is a String and matches" do
        GDor::Indexer::SolrDocHash.new({:foo => "a"}).field_present?(:foo, 'a').should == true
      end
      it "false if hash[field] is a String and doesn't match" do
        GDor::Indexer::SolrDocHash.new({:foo => "a"}).field_present?(:foo, 'b').should == false
      end
      it "true if hash[field] is an Array with a value that matches" do
        GDor::Indexer::SolrDocHash.new({:foo => ["a", "b"]}).field_present?(:foo, 'a').should == true
      end
      it "false if hash[field] is an Array with no value that matches" do
        GDor::Indexer::SolrDocHash.new({:foo => ["a", "b"]}).field_present?(:foo, 'c').should == false
      end
      it "false if hash[field] is not a String or Array" do
        GDor::Indexer::SolrDocHash.new({:foo => {}}).field_present?(:foo, 'a').should == false
      end
    end
    
    context "expected value is Regex" do
      it "true if hash[field] is a String and matches" do
        GDor::Indexer::SolrDocHash.new({:foo => "aba"}).field_present?(:foo, /b/).should == true
      end
      it "false if hash[field] is a String and doesn't match" do
        GDor::Indexer::SolrDocHash.new({:foo => "aaaaa"}).field_present?(:foo, /b/).should == false
      end
      it "true if hash[field] is an Array with a value that matches" do
        GDor::Indexer::SolrDocHash.new({:foo => ["a", "b"]}).field_present?(:foo, /b/).should == true
      end
      it "false if hash[field] is an Array with no value that matches" do
        GDor::Indexer::SolrDocHash.new({:foo => ["a", "b"]}).field_present?(:foo, /c/).should == false
      end
      it "false if hash[field] is not a String or Array" do
        GDor::Indexer::SolrDocHash.new({:foo => {}}).field_present?(:foo, /a/).should == false
      end
    end
  end # field_present?


  context "#combine" do
    context "orig has no key" do
      subject do
        GDor::Indexer::SolrDocHash.new({})
      end

      it "result has no key if new value is nil" do
        subject.combine({:foo => nil}).should == {}
      end
      it "result has no key if new value is empty String" do
        subject.combine({:foo => ""}).should == {}
      end
      it "result has new value if new value is non-empty String" do
        subject.combine({:foo => 'bar'}).should == {:foo => 'bar'}
      end
      it "result has no key if new value is empty Array" do
        subject.combine({:foo => []}).should == {}
      end
      it "result has new value new value is non-empty Array" do
        subject.combine({:foo => ['bar']}).should == {:foo => ['bar']}
      end
      it "result has no key if new value is not String or Array" do
        subject.combine({:foo => {}}).should == {}
      end
    end # orig has no key
    context "orig value is nil" do
      subject do
        GDor::Indexer::SolrDocHash.new(:foo => nil)
      end
      it "result has no key if new value is nil" do
        subject.combine({:foo => nil}).should == {}
      end
      it "result has no key if new value is empty String" do
        subject.combine({:foo => ""}).should == {}
      end
      it "result has new value if new value is non-empty String" do
        subject.combine({:foo => 'bar'}).should == {:foo => 'bar'}
      end
      it "result has no key if new value is empty Array" do
        subject.combine({:foo => []}).should == {}
      end
      it "result has new value if new value is non-empty Array" do
        subject.combine({:foo => ['bar']}).should == {:foo => ['bar']}
      end
      it "result has no key if new value is not String or Array" do
        subject.combine({:foo => {}}).should == {}
      end
    end # orig value is nil
    context "orig value is empty String" do
      subject do
        GDor::Indexer::SolrDocHash.new(:foo => "")
      end
      it "result has no key if new value is nil" do
        subject.combine({:foo => nil}).should == {}
      end
      it "result has no key if new value is empty String" do
        subject.combine({:foo => ""}).should == {}
      end
      it "result has new value if new value is non-empty String" do
        subject.combine({:foo => 'bar'}).should == {:foo => 'bar'}
      end
      it "result has no key if new value is empty Array" do
        subject.combine({:foo => []}).should == {}
      end
      it "result has new value if new value is non-empty Array" do
        subject.combine({:foo => ['bar']}).should == {:foo => ['bar']}
      end
      it "result has no key if new value is not String or Array" do
        subject.combine({:foo => {}}).should == {}
      end
    end # orig value is empty String
    context "orig value is non-empty String" do
      subject do
        GDor::Indexer::SolrDocHash.new(:foo => "a")
      end
      it "result is orig value if new value is nil" do
        subject.combine({:foo => nil}).should == {:foo => "a"}
      end
      it "result is orig value if new value is empty String" do
        subject.combine({:foo => ""}).should == {:foo => "a"}
      end
      it "result is Array of old and new values if new value is non-empty String" do
        subject.combine({:foo => 'bar'}).should == {:foo => ["a", 'bar']}
      end
      it "result is orig value if new value is empty Array" do
        subject.combine({:foo => []}).should == {:foo => "a"}
      end
      it "result Array of old and new values if new value is non-empty Array" do
        subject.combine({:foo => ['bar', 'ness']}).should == {:foo => ["a", 'bar', 'ness']}
      end
      it "result is orig value if new value is not String or Array" do
        subject.combine({:foo => :bar}).should == {:foo => "a"}
      end
    end # orig value is String
    context "orig value is empty Array" do
      subject do
        GDor::Indexer::SolrDocHash.new(:foo => [])
      end
      it "result has no key if new value is nil" do
        subject.combine({:foo => nil}).should == {}
      end
      it "result has no key if new value is empty String" do
        subject.combine({:foo => ""}).should == {}
      end
      it "result is new value if new value is non-empty String" do
        subject.combine({:foo => 'bar'}).should == {:foo => 'bar'}
      end
      it "result has no key if new value is empty Array" do
        subject.combine({:foo => []}).should == {}
      end
      it "result is new values if new value is non-empty Array" do
        subject.combine({:foo => ['bar', 'ness']}).should == {:foo => ['bar', 'ness']}
      end
      it "result has no key if new value is not String or Array" do
        subject.combine({:foo => {}}).should == {}
      end
    end # orig value is empty Array
    context "orig value is non-empty Array" do
      subject do
        GDor::Indexer::SolrDocHash.new(:foo => ["a", "b"])
      end
      it "result is orig value if new value is nil" do
        subject.combine({:foo => nil}).should == {:foo => ["a", "b"]}
      end
      it "result is orig value if new value is empty String" do
        subject.combine({:foo => ""}).should == {:foo => ["a", "b"]}
      end
      it "result is Array of old and new values if new value is non-empty String" do
        subject.combine({:foo => 'bar'}).should == {:foo => ["a", "b", 'bar']}
      end
      it "result is orig value if new value is empty Array" do
        subject.combine({:foo => []}).should == {:foo => ["a", "b"]}
      end
      it "result Array of old and new values if new value is non-empty Array" do
        subject.combine({:foo => ['bar', 'ness']}).should == {:foo => ["a", "b", 'bar', 'ness']}
      end
      it "result is orig value if new value is not String or Array" do
        subject.combine({:foo => :bar}).should == {:foo => ["a", "b"]}
      end
    end # orig value is non-empty Array
  end # combine

end
