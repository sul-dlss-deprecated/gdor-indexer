require 'stanford-mods'
 
# A mixin to the SolrDocBuilder class.
# Methods for SearchWorks Solr field values
class SolrDocBuilder

  # ---- TITLE METHODS ----
  def title_245a_search
    @mods.short_titles.first
  end
  
  def title_245_search
    @mods.full_titles.first
  end
  
  def title_variant_search
    @mods.alternative_titles
  end

  def title_sort
    @mods.sort_title
  end
  
  
end