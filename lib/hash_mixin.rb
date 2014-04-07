# add the field_present? method to the Hash class
class Hash  

  # looks for non-empty existence of field when exp_val is nil;
  # when exp_val is a String, looks for matching value as a String or as a member of an Array
  # when exp_val is a Regexp, looks for String value that matches, or Array with a String member that matches
  # @return true if the field is non-trivially present in the hash, false otherwise
  def field_present? field, exp_val = nil
    if self[field] && (self[field].instance_of?(String) || self[field].instance_of?(Array)) && self[field].length > 0 
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
  
  # merge in field values from the new hash, with the following guarantees:
  #  values for keys in new_hash will be a non-empty String or flat Array 
  #  keys will be removed from hash if all values are nil or empty 
  def combine new_hash
    new_hash.each_key { |key| 
      # only pay attention to real new values
      new_val = new_hash[key] if new_hash[key] && (new_hash[key].instance_of?(String) || new_hash[key].instance_of?(Array)) && new_hash[key].length > 0

      if self[key] && (self[key].instance_of?(String) || self[key].instance_of?(Array)) && self[key].length > 0 
        orig_val = self[key]
        if orig_val.instance_of?(String)
          if new_val
            self[key] = [orig_val, new_val].flatten.uniq
          end
        elsif orig_val.instance_of?(Array)
          if new_val
            self[key] = [orig_val, new_val].flatten.uniq
          end
        end
      else # no old value
        if new_val
          self[key] = new_val
        else
          self.delete(key)
        end
      end
    }
    self
  end
  
end
