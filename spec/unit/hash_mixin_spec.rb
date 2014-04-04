require 'hash_mixin'

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
      it "false if doc_hash[field] is nil" do
        {:foo => nil}.field_present?(:foo).should == false
      end
      it "false if doc_hash[field] is an empty String" do
        {:foo => ""}.field_present?(:foo).should == false
      end
      it "true if doc_hash[field] is a non-empty String" do
        {:foo => 'bar'}.field_present?(:foo).should == true
      end
      it "false if doc_hash[field] is an empty Array" do
        {:foo => []}.field_present?(:foo).should == false
      end
      it "false if doc_hash[field] is an Array with only empty string values" do
        {:foo => ["", ""]}.field_present?(:foo).should == false
      end
      it "true if doc_hash[field] is a non-empty Array" do
        {:foo => ["a"]}.field_present?(:foo).should == true
      end
      it "false if doc_hash[field] is not a String or Array" do
        {:foo => {}}.field_present?(:foo).should == false
      end
    end
    
    context "expected value is a String" do
      it "true if doc_hash[field] is a String and matches" do
        {:foo => "a"}.field_present?(:foo, 'a').should == true
      end
      it "false if doc_hash[field] is a String and doesn't match" do
        {:foo => "a"}.field_present?(:foo, 'b').should == false
      end
      it "true if doc_hash[field] is an Array with a value that matches" do
        {:foo => ["a", "b"]}.field_present?(:foo, 'a').should == true
      end
      it "false if doc_hash[field] is an Array with no value that matches" do
        {:foo => ["a", "b"]}.field_present?(:foo, 'c').should == false
      end
      it "false if doc_hash[field] is not a String or Array" do
        {:foo => {}}.field_present?(:foo, 'a').should == false
      end
    end
    
    context "expected value is Regex" do
      it "true if doc_hash[field] is a String and matches" do
        {:foo => "aba"}.field_present?(:foo, /b/).should == true
      end
      it "false if doc_hash[field] is a String and doesn't match" do
        {:foo => "aaaaa"}.field_present?(:foo, /b/).should == false
      end
      it "true if doc_hash[field] is an Array with a value that matches" do
        {:foo => ["a", "b"]}.field_present?(:foo, /b/).should == true
      end
      it "false if doc_hash[field] is an Array with no value that matches" do
        {:foo => ["a", "b"]}.field_present?(:foo, /c/).should == false
      end
      it "false if doc_hash[field] is not a String or Array" do
        {:foo => {}}.field_present?(:foo, /a/).should == false
      end
    end
  end # field_present?
end
