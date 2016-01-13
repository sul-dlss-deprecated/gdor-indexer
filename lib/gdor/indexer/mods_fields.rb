# A mixin to the GDor::Indexer::SolrDocBuilder class.
# Methods for Solr field values determined from MODS
module GDor::Indexer::ModsFields
  # Create a Hash representing a Solr doc, with all MODS related fields populated.
  # @return [Hash] Hash representing the Solr document
  def doc_hash_from_mods
    pub_year_w_approx_dates = smods_rec.pub_year_int(false)
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

      language: smods_rec.sw_language_facet,
      physical: smods_rec.term_values([:physical_description, :extent]),
      summary_search: smods_rec.term_values(:abstract),
      toc_search: smods_rec.term_values(:tableOfContents),
      url_suppl: smods_rec.term_values([:related_item, :location, :url]),

      # publication fields
      pub_search: smods_rec.place,
      pub_year_isi: pub_year_w_approx_dates, # for sorting
      # TODO:  remove pub_date_sort after reindexing existing colls;  deprecated in favor of pub_year_isi ...
      pub_date_sort: smods_rec.pub_year_sort_str(false),
      # these are for single value facet display (in leiu of date slider (pub_year_tisim) )
      pub_year_no_approx_isi: smods_rec.pub_year_int(true),
      pub_year_w_approx_isi: pub_year_w_approx_dates,
      # display fields  TODO:  pub_date_display is deprecated;  need better implementation of imprint_display
      imprint_display: smods_rec.pub_date_display,
      # pub_date_best_sort_str_value is protected ...
      creation_year_isi: smods_rec.year_int(smods_rec.date_created_elements(false)),
      publication_year_isi: smods_rec.year_int(smods_rec.date_issued_elements(false)),

      all_search: smods_rec.text.gsub(/\s+/, ' ')
    }

    add_pub_year_tisim(doc_hash)
  end

  private

  # call stanford-mods format_main to get results
  # @return [Array<String>] value(s) in the SearchWorks controlled vocabulary, or []
  def format_main_ssim
    vals = smods_rec.format_main
    if vals.empty?
      logger.warn "#{druid} has no SearchWorks Resource Type from MODS - check <typeOfResource> and other implicated MODS elements"
    end
    vals
  end

  # add pub_year_tisim (for Date Slider; positive values only) to doc_hash
  # @param [Hash] Hash representing the Solr document
  # @return [Hash] updated Hash representing the Solr document
  def add_pub_year_tisim(doc_hash)
    pub_date_sort_val = doc_hash[:pub_year_isi]
    if is_positive_int? pub_date_sort_val
      doc_hash[:pub_year_tisim] = pub_date_sort_val # for date slider
    end
    doc_hash
  end

  # @return true if the string parses into an int, and if so, the int is >= 0
  def is_positive_int?(str)
    str.to_i >= 0
  rescue
    false
  end
end
