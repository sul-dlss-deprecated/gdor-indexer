require 'stanford-mods'
 
# A mixin to the SolrDocBuilder class.
# Methods for SearchWorks Solr field values
class SolrDocBuilder

  # ---- TITLES ----
  def title_245a_search
    @mods.sw_short_title
  end
  def title_245_search
    @mods.sw_full_title
  end
  def title_variant_search
    @mods.sw_addl_titles
  end
  def title_sort
    @mods.sw_sort_title
  end
  alias :title_245a_display :title_245a_search
  alias :title_display :title_245_search
  alias :title_full_display :title_245_search
  
  # ---- AUTHORS ----
  def author_1xx_search
    @mods.sw_main_author
  end
  def author_7xx_search
    @mods.sw_addl_authors
  end
  def author_person_facet
    @mods.sw_person_authors
  end
  def author_other_facet
    @mods.sw_impersonal_authors
  end
  def author_sort
    @mods.sw_sort_author
  end
  def author_corp_display
    @mods.sw_corporate_authors
  end
  def author_meeting_display
    @mods.sw_meeting_authors
  end
  alias :author_person_display :author_person_facet
  alias :author_person_full_display :author_person_facet
  
end