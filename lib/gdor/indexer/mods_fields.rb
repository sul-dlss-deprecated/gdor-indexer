# A mixin to the GDor::Indexer::SolrDocBuilder class.
# Methods for Solr field values determined from MODS
module GDor::Indexer::ModsFields
  # Create a Hash representing a Solr doc, with all MODS related fields populated.
  # @return [Hash] Hash representing the Solr document
  def doc_hash_from_mods
    doc_hash = {
      # title fields
      title_245a_search: smods_rec.sw_short_title,
      title_245_search: smods_rec.sw_full_title,
      title_variant_search: smods_rec.sw_addl_titles,
      title_sort: smods_rec.sw_sort_title,
      title_245a_display: smods_rec.sw_short_title,
      title_display: smods_rec.sw_title_display,
      title_full_display: smods_rec.sw_full_title,

      # author fields
      author_1xx_search: smods_rec.sw_main_author,
      author_7xx_search: smods_rec.sw_addl_authors,
      author_person_facet: smods_rec.sw_person_authors,
      author_other_facet: smods_rec.sw_impersonal_authors,
      author_sort: smods_rec.sw_sort_author,
      author_corp_display: smods_rec.sw_corporate_authors,
      author_meeting_display: smods_rec.sw_meeting_authors,
      author_person_display: smods_rec.sw_person_authors,
      author_person_full_display: smods_rec.sw_person_authors,

      # subject search fields
      topic_search: smods_rec.topic_search,
      geographic_search: smods_rec.geographic_search,
      subject_other_search: smods_rec.subject_other_search,
      subject_other_subvy_search: smods_rec.subject_other_subvy_search,
      subject_all_search: smods_rec.subject_all_search,
      topic_facet: smods_rec.topic_facet,
      geographic_facet: smods_rec.geographic_facet,
      era_facet: smods_rec.era_facet,

      format_main_ssim: format_main_ssim,
      format: format, # for backwards compatibility

      language: smods_rec.sw_language_facet,
      physical: smods_rec.term_values([:physical_description, :extent]),
      summary_search: smods_rec.term_values(:abstract),
      toc_search: smods_rec.term_values(:tableOfContents),
      url_suppl: smods_rec.term_values([:related_item, :location, :url]),

      # publication fields
      pub_search: smods_rec.place,
      pub_date_sort: smods_rec.pub_date_sort,
      imprint_display: smods_rec.pub_date_display,
      pub_date: smods_rec.pub_date_facet,
      pub_date_display: smods_rec.pub_date_display, # pub_date_display may be deprecated

      all_search: smods_rec.text.gsub(/\s+/, ' ')
    }

    # more pub date fields
    pub_date_sort = doc_hash[:pub_date_sort]
    if is_positive_int? pub_date_sort
      doc_hash[:pub_year_tisim] = pub_date_sort # for date slider
      # put the displayable year in the correct field, :creation_year_isi for example
      doc_hash[date_type_sym] = smods_rec.pub_date_sort if date_type_sym
    end

    doc_hash
  end

  # select one or more format values from the controlled vocabulary here:
  #   http://searchworks-solr-lb.stanford.edu:8983/solr/select?facet.field=format&rows=0&facet.sort=index
  # via stanford-mods gem
  # @return [Array<String>] value(s) in the SearchWorks controlled vocabulary, or []
  def format
    vals = smods_rec.format
    if vals.empty?
      logger.warn "#{druid} has no SearchWorks format from MODS - check <typeOfResource> and other implicated MODS elements"
    end
    vals
  end

  # call stanford-mods format_main to get results
  # @return [Array<String>] value(s) in the SearchWorks controlled vocabulary, or []
  def format_main_ssim
    vals = smods_rec.format_main
    if vals.empty?
      logger.warn "#{druid} has no SearchWorks Resource Type from MODS - check <typeOfResource> and other implicated MODS elements"
    end
    vals
  end

  # call stanford-mods sw_genre to get results
  # @return [Array<String>] value(s)
  def genre_ssim
    smods_rec.sw_genre
  end

  protected

  # @return true if the string parses into an int, and if so, the int is >= 0
  def is_positive_int?(str)
    str.to_i >= 0
  rescue
    false
  end

  # determines particular flavor of displayable publication year field
  # @return Solr field name as a symbol
  def date_type_sym
    vals = smods_rec.term_values([:origin_info, :dateIssued])
    return :publication_year_isi if vals && vals.length > 0
    vals = smods_rec.term_values([:origin_info, :dateCreated])
    return :creation_year_isi if vals && vals.length > 0
    nil
  end
end
