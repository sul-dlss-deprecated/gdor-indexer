describe GDor::Indexer::ModsFields do
  let(:fake_druid) { 'oo000oo0000' }
  let(:ns_decl) { "xmlns='#{Mods::MODS_NS}'" }
  let(:mods_xml) { "<mods #{ns_decl}><note>gdor_mods_fields testing</note></mods>" }

  def sdb_for_mods(m)
    resource = Harvestdor::Indexer::Resource.new(double, fake_druid)
    allow(resource).to receive(:public_xml).and_return(nil)
    allow(resource).to receive(:mods).and_return(Nokogiri::XML(m))
    i = Harvestdor::Indexer.new
    i.logger.level = Logger::WARN
    allow(resource).to receive(:indexer).and_return(i)
    lgr = Logger.new(StringIO.new)
    lgr.level = Logger::WARN
    GDor::Indexer::SolrDocBuilder.new(resource, lgr)
  end

  # see https://consul.stanford.edu/display/NGDE/Required+and+Recommended+Solr+Fields+for+SearchWorks+documents

  context 'summary_search solr field from <abstract>' do
    it 'is populated when the MODS has a top level <abstract> element' do
      m = "<mods #{ns_decl}><abstract>blah blah</abstract></mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.doc_hash_from_mods[:summary_search]).to match_array ['blah blah']
    end
    it 'has a value for each abstract element' do
      m = "<mods #{ns_decl}>
        <abstract>one</abstract>
        <abstract>two</abstract>
      </mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.doc_hash_from_mods[:summary_search]).to match_array %w(one two)
    end
    it 'does not be present when there is no top level <abstract> element' do
      m = "<mods #{ns_decl}><relatedItem><abstract>blah blah</abstract></relatedItem></mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.doc_hash_from_mods[:summary_search]).to be_nil
    end
    it 'does not be present if there are only empty abstract elements in the MODS' do
      m = "<mods #{ns_decl}><abstract/><note>notit</note></mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.doc_hash_from_mods[:summary_search]).to be_nil
    end
    it 'summary_display should not be populated - it is a copy field' do
      m = "<mods #{ns_decl}><abstract>blah blah</abstract></mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.doc_hash_from_mods[:summary_display]).to be_nil
    end
  end # summary_search / <abstract>

  it 'language: should call sw_language_facet in stanford-mods gem to populate language field' do
    sdb = sdb_for_mods(mods_xml)
    smr = sdb.smods_rec
    expect(smr).to receive(:sw_language_facet)
    sdb.doc_hash_from_mods
  end

  context 'physical solr field from <physicalDescription><extent>' do
    it 'is populated when the MODS has mods/physicalDescription/extent element' do
      m = "<mods #{ns_decl}><physicalDescription><extent>blah blah</extent></physicalDescription></mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.doc_hash_from_mods[:physical]).to match_array ['blah blah']
    end
    it 'has a value for each extent element' do
      m = "<mods #{ns_decl}>
        <physicalDescription>
          <extent>one</extent>
          <extent>two</extent>
        </physicalDescription>
        <physicalDescription><extent>three</extent></physicalDescription>
      </mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.doc_hash_from_mods[:physical]).to match_array %w(one two three)
    end
    it 'does not be present when there is no top level <physicalDescription> element' do
      m = "<mods #{ns_decl}><relatedItem><physicalDescription><extent>foo</extent></physicalDescription></relatedItem></mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.doc_hash_from_mods[:physical]).to be_nil
    end
    it 'does not be present if there are only empty physicalDescription or extent elements in the MODS' do
      m = "<mods #{ns_decl}><physicalDescription/><physicalDescription><extent/></physicalDescription><note>notit</note></mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.doc_hash_from_mods[:physical]).to be_nil
    end
  end # physical field from physicalDescription/extent

  context 'url_suppl solr field from /mods/relatedItem/location/url' do
    it 'is populated when the MODS has mods/relatedItem/location/url' do
      m = "<mods #{ns_decl}><relatedItem><location><url>url.org</url></location></relatedItem></mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.doc_hash_from_mods[:url_suppl]).to match_array ['url.org']
    end
    it 'has a value for each mods/relatedItem/location/url element' do
      m = "<mods #{ns_decl}>
        <relatedItem>
          <location><url>one</url></location>
          <location>
            <url>two</url>
            <url>three</url>
          </location>
        </relatedItem>
        <relatedItem><location><url>four</url></location></relatedItem>
      </mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.doc_hash_from_mods[:url_suppl]).to match_array %w(one two three four)
    end
    it 'does not be populated from /mods/location/url element' do
      m = "<mods #{ns_decl}><location><url>hi</url></location></mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.doc_hash_from_mods[:url_suppl]).to be_nil
    end
    it 'does not be present if there are only empty relatedItem/location/url elements in the MODS' do
      m = "<mods #{ns_decl}>
        <relatedItem><location><url/></location></relatedItem>
        <relatedItem><location/></relatedItem>
        <relatedItem/><note>notit</note></mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.doc_hash_from_mods[:url_suppl]).to be_nil
    end
  end

  context 'toc_search solr field from <tableOfContents>' do
    it 'has a value for each tableOfContents element' do
      m = "<mods #{ns_decl}>
      <tableOfContents>one</tableOfContents>
      <tableOfContents>two</tableOfContents>
      </mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.doc_hash_from_mods[:toc_search]).to match_array %w(one two)
    end
    it 'does not be present when there is no top level <tableOfContents> element' do
      m = "<mods #{ns_decl}><relatedItem><tableOfContents>foo</tableOfContents></relatedItem></mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.doc_hash_from_mods[:toc_search]).to be_nil
    end
    it 'does not be present if there are only empty tableOfContents elements in the MODS' do
      m = "<mods #{ns_decl}><tableOfContents/><note>notit</note></mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.doc_hash_from_mods[:toc_search]).to be_nil
    end
  end

  context '#format_main_ssim' do
    it 'doc_hash_from_mods calls #format_main_ssim' do
      m = "<mods #{ns_decl}><note>nope</typeOfResource></mods>"
      sdb = sdb_for_mods(m)
      expect(sdb).to receive(:format_main_ssim)
      sdb.doc_hash_from_mods[:format_main_ssim]
    end
    it '#format_main_ssim calls stanford-mods.format_main' do
      m = "<mods #{ns_decl}><note>nope</typeOfResource></mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.smods_rec).to receive(:format_main).and_return([])
      sdb.send(:format_main_ssim)
    end
    it 'has a value when MODS data provides' do
      m = "<mods #{ns_decl}><typeOfResource>still image</typeOfResouce></mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.send(:format_main_ssim)).to match_array ['Image']
    end
    it 'returns empty Array and logs warning if there is no value' do
      sdb = sdb_for_mods(mods_xml)
      expect(sdb.logger).to receive(:warn).with("#{fake_druid} has no SearchWorks Resource Type from MODS - check <typeOfResource> and other implicated MODS elements")
      expect(sdb.send(:format_main_ssim)).to eq([])
    end
  end

  context 'title fields' do
    let(:title_mods) do
      "<mods #{ns_decl}>
        <titleInfo>
          <title>Jerk</title>
          <nonSort>The</nonSort>
          <subTitle>is whom?</subTitle>
        </titleInfo>
        <titleInfo>
          <title>Joke</title>
        </titleInfo>
        <titleInfo type='alternative'>
          <title>Alternative</title>
        </titleInfo>
      </mods>"
    end
    let(:sdb) { sdb_for_mods(title_mods) }
    let(:title_doc_hash) { sdb.doc_hash_from_mods }

    it 'calls the appropriate methods in the stanford-mods gem to populate the fields' do
      smr = sdb.smods_rec
      expect(smr).to receive(:sw_short_title).at_least(:once)
      expect(smr).to receive(:sw_full_title).at_least(:once)
      expect(smr).to receive(:sw_title_display)
      expect(smr).to receive(:sw_addl_titles)
      expect(smr).to receive(:sw_sort_title)
      sdb.doc_hash_from_mods
    end
    context 'search fields' do
      it 'title_245a_search' do
        expect(title_doc_hash[:title_245a_search]).to eq('The Jerk')
      end
      it 'title_245_search' do
        expect(title_doc_hash[:title_245_search]).to eq('The Jerk : is whom?')
      end
      it 'title_variant_search' do
        expect(title_doc_hash[:title_variant_search]).to match_array %w(Joke Alternative)
      end
      it 'title_related_search should not be populated from MODS' do
        expect(title_doc_hash[:title_related_search]).to be_nil
      end
    end
    context 'display fields' do
      it 'title_display' do
        expect(title_doc_hash[:title_display]).to eq('The Jerk : is whom?')
      end
      it 'title_245a_display' do
        expect(title_doc_hash[:title_245a_display]).to eq('The Jerk')
      end
      it 'title_245c_display should not be populated from MODS' do
        expect(title_doc_hash[:title_245c_display]).to be_nil
      end
      it 'title_full_display' do
        expect(title_doc_hash[:title_full_display]).to eq('The Jerk : is whom?')
      end
      it 'removes trailing commas in title_display' do
        title_mods = "<mods #{ns_decl}>
        <titleInfo><title>Jerk</title><nonSort>The</nonSort><subTitle>is whom,</subTitle></titleInfo>
        <titleInfo><title>Joke</title></titleInfo>
        <titleInfo type='alternative'><title>Alternative</title></titleInfo>
        </mods>"
        sdb = sdb_for_mods(title_mods)
        title_doc_hash = sdb.doc_hash_from_mods
        expect(title_doc_hash[:title_display]).to eq('The Jerk : is whom')
      end
      it 'title_variant_display should not be populated - it is a copy field' do
        expect(title_doc_hash[:title_variant_display]).to be_nil
      end
    end
    it 'title_sort' do
      expect(title_doc_hash[:title_sort]).to eq('Jerk is whom')
    end
  end # title fields

  context 'author fields' do
    let(:name_mods) do
      "<mods #{ns_decl}>
        <name type='personal'>
          <namePart type='given'>John</namePart>
          <namePart type='family'>Huston</namePart>
          <role><roleTerm type='code' authority='marcrelator'>drt</roleTerm></role>
          <displayForm>q</displayForm>
        </name>
        <name type='personal'><namePart>Crusty The Clown</namePart></name>
        <name type='corporate'><namePart>Watchful Eye</namePart></name>
        <name type='corporate'>
          <namePart>Exciting Prints</namePart>
          <role><roleTerm type='text'>lithographer</roleTerm></role>
        </name>
        <name type='conference'><namePart>conference</namePart></name>
      </mods>"
    end
    let(:sdb) { sdb_for_mods(name_mods) }
    let(:author_doc_hash) { sdb.doc_hash_from_mods }

    it 'calls the appropriate methods in the stanford-mods gem to populate the fields' do
      smr = sdb.smods_rec
      expect(smr).to receive(:sw_main_author)
      expect(smr).to receive(:sw_addl_authors)
      expect(smr).to receive(:sw_person_authors).exactly(3).times
      expect(smr).to receive(:sw_impersonal_authors)
      expect(smr).to receive(:sw_corporate_authors)
      expect(smr).to receive(:sw_meeting_authors)
      expect(smr).to receive(:sw_sort_author)
      sdb.doc_hash_from_mods
    end
    context 'search fields' do
      it 'author_1xx_search' do
        expect(author_doc_hash[:author_1xx_search]).to eq('Crusty The Clown')
      end
      it 'author_7xx_search' do
        skip 'Should this return all authors? or only 7xx authors?'
        expect(author_doc_hash[:author_7xx_search]).to match_array ['q', 'Watchful Eye', 'Exciting Prints', 'conference']
      end
      it 'author_8xx_search should not be populated from MODS' do
        expect(author_doc_hash[:author_8xx_search]).to be_nil
      end
    end
    context 'facet fields' do
      it 'author_person_facet' do
        expect(author_doc_hash[:author_person_facet]).to match_array ['q', 'Crusty The Clown']
      end
      it 'author_other_facet' do
        expect(author_doc_hash[:author_other_facet]).to match_array ['Watchful Eye', 'Exciting Prints', 'conference']
      end
    end
    context 'display fields' do
      it 'author_person_display' do
        expect(author_doc_hash[:author_person_display]).to match_array ['q', 'Crusty The Clown']
      end
      it 'author_person_full_display' do
        expect(author_doc_hash[:author_person_full_display]).to match_array ['q', 'Crusty The Clown']
      end
      it 'author_corp_display' do
        expect(author_doc_hash[:author_corp_display]).to match_array ['Watchful Eye', 'Exciting Prints']
      end
      it 'author_meeting_display' do
        expect(author_doc_hash[:author_meeting_display]).to match_array ['conference']
      end
    end
    it 'author_sort' do
      expect(author_doc_hash[:author_sort]).to eq('Crusty The Clown')
    end
  end # author fields

  # subject fields moved to mods_subject_fields_spec.rb
  # publication fields moved to mods_pub_fields_spec.rb
end
