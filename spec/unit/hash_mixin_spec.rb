require 'spec_helper'

describe Hash do
  context "#field_present?" do
    
    context "actual field value is boolean true" do
      it "true if expected value is nil" do
        {:a => true}.field_present?(:a).should == false
      end
      it "false if expected value is String" do
        {:a => true}.field_present?(:a, 'true').should == false
      end
      it "false if expected value is Regex" do
        {:a => true}.field_present?(:a => /true/).should == false
      end
    end

    context "expected value is nil" do
      it "false if the field is not in the doc_hash" do
        {}.field_present?(:any).should == false
      end
      it "false if hash[field] is nil" do
        {:foo => nil}.field_present?(:foo).should == false
      end
      it "false if hash[field] is an empty String" do
        {:foo => ""}.field_present?(:foo).should == false
      end
      it "true if hash[field] is a non-empty String" do
        {:foo => 'bar'}.field_present?(:foo).should == true
      end
      it "false if hash[field] is an empty Array" do
        {:foo => []}.field_present?(:foo).should == false
      end
      it "false if hash[field] is an Array with only empty String values" do
        {:foo => ["", ""]}.field_present?(:foo).should == false
      end
      it "false if hash[field] is an Array with only nil String values" do
        {:foo => [nil]}.field_present?(:foo).should == false
      end
      it "true if hash[field] is a non-empty Array" do
        {:foo => ["a"]}.field_present?(:foo).should == true
      end
      it "false if doc_hash[field] is not a String or Array" do
        {:foo => {}}.field_present?(:foo).should == false
      end
    end
    
    context "expected value is a String" do
      it "true if hash[field] is a String and matches" do
        {:foo => "a"}.field_present?(:foo, 'a').should == true
      end
      it "false if hash[field] is a String and doesn't match" do
        {:foo => "a"}.field_present?(:foo, 'b').should == false
      end
      it "true if hash[field] is an Array with a value that matches" do
        {:foo => ["a", "b"]}.field_present?(:foo, 'a').should == true
      end
      it "false if hash[field] is an Array with no value that matches" do
        {:foo => ["a", "b"]}.field_present?(:foo, 'c').should == false
      end
      it "false if hash[field] is not a String or Array" do
        {:foo => {}}.field_present?(:foo, 'a').should == false
      end
    end
    
    context "expected value is Regex" do
      it "true if hash[field] is a String and matches" do
        {:foo => "aba"}.field_present?(:foo, /b/).should == true
      end
      it "false if hash[field] is a String and doesn't match" do
        {:foo => "aaaaa"}.field_present?(:foo, /b/).should == false
      end
      it "true if hash[field] is an Array with a value that matches" do
        {:foo => ["a", "b"]}.field_present?(:foo, /b/).should == true
      end
      it "false if hash[field] is an Array with no value that matches" do
        {:foo => ["a", "b"]}.field_present?(:foo, /c/).should == false
      end
      it "false if hash[field] is not a String or Array" do
        {:foo => {}}.field_present?(:foo, /a/).should == false
      end
    end
  end # field_present?


  context "#combine" do
    context "orig has no key" do
      it "result has no key if new value is nil" do
        {}.combine({:foo => nil}).should == {}
      end
      it "result has no key if new value is empty String" do
        {}.combine({:foo => ""}).should == {}
      end
      it "result has new value if new value is non-empty String" do
        {}.combine({:foo => 'bar'}).should == {:foo => 'bar'}
      end
      it "result has no key if new value is empty Array" do
        {}.combine({:foo => []}).should == {}
      end
      it "result has new value new value is non-empty Array" do
        {}.combine({:foo => ['bar']}).should == {:foo => ['bar']}
      end
      it "result has no key if new value is not String or Array" do
        {}.combine({:foo => {}}).should == {}
      end
    end # orig has no key
    context "orig value is nil" do
      it "result has no key if new value is nil" do
        {:foo => nil}.combine({:foo => nil}).should == {}
      end
      it "result has no key if new value is empty String" do
        {:foo => nil}.combine({:foo => ""}).should == {}
      end
      it "result has new value if new value is non-empty String" do
        {:foo => nil}.combine({:foo => 'bar'}).should == {:foo => 'bar'}
      end
      it "result has no key if new value is empty Array" do
        {:foo => nil}.combine({:foo => []}).should == {}
      end
      it "result has new value if new value is non-empty Array" do
        {:foo => nil}.combine({:foo => ['bar']}).should == {:foo => ['bar']}
      end
      it "result has no key if new value is not String or Array" do
        {:foo => nil}.combine({:foo => {}}).should == {}
      end
    end # orig value is nil
    context "orig value is empty String" do
      it "result has no key if new value is nil" do
        {:foo => ""}.combine({:foo => nil}).should == {}
      end
      it "result has no key if new value is empty String" do
        {:foo => ""}.combine({:foo => ""}).should == {}
      end
      it "result has new value if new value is non-empty String" do
        {:foo => ""}.combine({:foo => 'bar'}).should == {:foo => 'bar'}
      end
      it "result has no key if new value is empty Array" do
        {:foo => ""}.combine({:foo => []}).should == {}
      end
      it "result has new value if new value is non-empty Array" do
        {:foo => ""}.combine({:foo => ['bar']}).should == {:foo => ['bar']}
      end
      it "result has no key if new value is not String or Array" do
        {:foo => ""}.combine({:foo => {}}).should == {}
      end
    end # orig value is empty String
    context "orig value is non-empty String" do
      it "result is orig value if new value is nil" do
        {:foo => "a"}.combine({:foo => nil}).should == {:foo => "a"}
      end
      it "result is orig value if new value is empty String" do
        {:foo => "a"}.combine({:foo => ""}).should == {:foo => "a"}
      end
      it "result is Array of old and new values if new value is non-empty String" do
        {:foo => "a"}.combine({:foo => 'bar'}).should == {:foo => ["a", 'bar']}
      end
      it "result is orig value if new value is empty Array" do
        {:foo => "a"}.combine({:foo => []}).should == {:foo => "a"}
      end
      it "result Array of old and new values if new value is non-empty Array" do
        {:foo => "a"}.combine({:foo => ['bar', 'ness']}).should == {:foo => ["a", 'bar', 'ness']}
      end
      it "result is orig value if new value is not String or Array" do
        {:foo => "a"}.combine({:foo => :bar}).should == {:foo => "a"}
      end
    end # orig value is String
    context "orig value is empty Array" do
      it "result has no key if new value is nil" do
        {:foo => []}.combine({:foo => nil}).should == {}
      end
      it "result has no key if new value is empty String" do
        {:foo => []}.combine({:foo => ""}).should == {}
      end
      it "result is new value if new value is non-empty String" do
        {:foo => []}.combine({:foo => 'bar'}).should == {:foo => 'bar'}
      end
      it "result has no key if new value is empty Array" do
        {:foo => []}.combine({:foo => []}).should == {}
      end
      it "result is new values if new value is non-empty Array" do
        {:foo => []}.combine({:foo => ['bar', 'ness']}).should == {:foo => ['bar', 'ness']}
      end
      it "result has no key if new value is not String or Array" do
        {:foo => []}.combine({:foo => {}}).should == {}
      end
    end # orig value is empty Array
    context "orig value is non-empty Array" do
      it "result is orig value if new value is nil" do
        {:foo => ["a", "b"]}.combine({:foo => nil}).should == {:foo => ["a", "b"]}
      end
      it "result is orig value if new value is empty String" do
        {:foo => ["a", "b"]}.combine({:foo => ""}).should == {:foo => ["a", "b"]}
      end
      it "result is Array of old and new values if new value is non-empty String" do
        {:foo => ["a", "b"]}.combine({:foo => 'bar'}).should == {:foo => ["a", "b", 'bar']}
      end
      it "result is orig value if new value is empty Array" do
        {:foo => ["a", "b"]}.combine({:foo => []}).should == {:foo => ["a", "b"]}
      end
      it "result Array of old and new values if new value is non-empty Array" do
        {:foo => ["a", "b"]}.combine({:foo => ['bar', 'ness']}).should == {:foo => ["a", "b", 'bar', 'ness']}
      end
      it "result is orig value if new value is not String or Array" do
        {:foo => ["a", "b"]}.combine({:foo => :bar}).should == {:foo => ["a", "b"]}
      end
    end # orig value is non-empty Array
  end # combine

end
