# add the field_present? method to the Hash class
class Hash  

  # looks for non-empty existence of field when exp_val is nil;
  # when exp_val is a String, looks for matching value as a String or as a member of an Array
  # when exp_val is a Regexp, looks for String value that matches, or Array with a String member that matches
  # @return true if the field is non-trivially present in the hash, false otherwise
  def field_present? field, exp_val = nil
    if self[field] && self[field].length > 0 
      actual = self[field]
      return true if exp_val == nil && ( !actual.instance_of?(Array) || actual.index { |s| s.length > 0 } )
      if exp_val.instance_of?(String)
        if actual.instance_of?(String)
          return true if actual == exp_val
        elsif actual.instance_of?(Array)
          return true if actual.include? exp_val
        end
      elsif exp_val.instance_of?(Regexp)
        if actual.instance_of?(String)
          return true if exp_val.match(actual)
        elsif actual.instance_of?(Array)
          return true if actual.index { |s| exp_val.match(s) }
        end
      end
    end
    false
  end
  
end
