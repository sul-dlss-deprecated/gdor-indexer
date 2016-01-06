require 'spec_helper'

describe GDor::Indexer::ModsFields do
  before(:all) do
    @fake_druid = 'oo000oo0000'
    @ns_decl = "xmlns='#{Mods::MODS_NS}'"
    @mods_xml = "<mods #{@ns_decl}><note>gdor_mods_fields testing</note></mods>"
  end

  def sdb_for_mods(m)
    resource = Harvestdor::Indexer::Resource.new(double, @fake_druid)
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
      m = "<mods #{@ns_decl}><abstract>blah blah</abstract></mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.doc_hash_from_mods[:summary_search]).to match_array ['blah blah']
    end
    it 'has a value for each abstract element' do
      m = "<mods #{@ns_decl}>
        <abstract>one</abstract>
        <abstract>two</abstract>
      </mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.doc_hash_from_mods[:summary_search]).to match_array %w(one two)
    end
    it 'does not be present when there is no top level <abstract> element' do
      m = "<mods #{@ns_decl}><relatedItem><abstract>blah blah</abstract></relatedItem></mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.doc_hash_from_mods[:summary_search]).to be_nil
    end
    it 'does not be present if there are only empty abstract elements in the MODS' do
      m = "<mods #{@ns_decl}><abstract/><note>notit</note></mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.doc_hash_from_mods[:summary_search]).to be_nil
    end
    it 'summary_display should not be populated - it is a copy field' do
      m = "<mods #{@ns_decl}><abstract>blah blah</abstract></mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.doc_hash_from_mods[:summary_display]).to be_nil
    end
  end # summary_search / <abstract>

  it 'language: should call sw_language_facet in stanford-mods gem to populate language field' do
    sdb = sdb_for_mods(@mods_xml)
    smr = sdb.smods_rec
    expect(smr).to receive(:sw_language_facet)
    sdb.doc_hash_from_mods
  end

  context 'physical solr field from <physicalDescription><extent>' do
    it 'is populated when the MODS has mods/physicalDescription/extent element' do
      m = "<mods #{@ns_decl}><physicalDescription><extent>blah blah</extent></physicalDescription></mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.doc_hash_from_mods[:physical]).to match_array ['blah blah']
    end
    it 'has a value for each extent element' do
      m = "<mods #{@ns_decl}>
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
      m = "<mods #{@ns_decl}><relatedItem><physicalDescription><extent>foo</extent></physicalDescription></relatedItem></mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.doc_hash_from_mods[:physical]).to be_nil
    end
    it 'does not be present if there are only empty physicalDescription or extent elements in the MODS' do
      m = "<mods #{@ns_decl}><physicalDescription/><physicalDescription><extent/></physicalDescription><note>notit</note></mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.doc_hash_from_mods[:physical]).to be_nil
    end
  end # physical field from physicalDescription/extent

  context 'url_suppl solr field from /mods/relatedItem/location/url' do
    it 'is populated when the MODS has mods/relatedItem/location/url' do
      m = "<mods #{@ns_decl}><relatedItem><location><url>url.org</url></location></relatedItem></mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.doc_hash_from_mods[:url_suppl]).to match_array ['url.org']
    end
    it 'has a value for each mods/relatedItem/location/url element' do
      m = "<mods #{@ns_decl}>
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
      m = "<mods #{@ns_decl}><location><url>hi</url></location></mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.doc_hash_from_mods[:url_suppl]).to be_nil
    end
    it 'does not be present if there are only empty relatedItem/location/url elements in the MODS' do
      m = "<mods #{@ns_decl}>
        <relatedItem><location><url/></location></relatedItem>
        <relatedItem><location/></relatedItem>
        <relatedItem/><note>notit</note></mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.doc_hash_from_mods[:url_suppl]).to be_nil
    end
  end

  context 'toc_search solr field from <tableOfContents>' do
    it 'has a value for each tableOfContents element' do
      m = "<mods #{@ns_decl}>
      <tableOfContents>one</tableOfContents>
      <tableOfContents>two</tableOfContents>
      </mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.doc_hash_from_mods[:toc_search]).to match_array %w(one two)
    end
    it 'does not be present when there is no top level <tableOfContents> element' do
      m = "<mods #{@ns_decl}><relatedItem><tableOfContents>foo</tableOfContents></relatedItem></mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.doc_hash_from_mods[:toc_search]).to be_nil
    end
    it 'does not be present if there are only empty tableOfContents elements in the MODS' do
      m = "<mods #{@ns_decl}><tableOfContents/><note>notit</note></mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.doc_hash_from_mods[:toc_search]).to be_nil
    end
  end

  context '#format_main_ssim' do
    it 'doc_hash_from_mods calls #format_main_ssim' do
      m = "<mods #{@ns_decl}><note>nope</typeOfResource></mods>"
      sdb = sdb_for_mods(m)
      expect(sdb).to receive(:format_main_ssim)
      sdb.doc_hash_from_mods[:format_main_ssim]
    end
    it '#format_main_ssim calls stanford-mods.format_main' do
      m = "<mods #{@ns_decl}><note>nope</typeOfResource></mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.smods_rec).to receive(:format_main).and_return([])
      sdb.format_main_ssim
    end
    it 'has a value when MODS data provides' do
      m = "<mods #{@ns_decl}><typeOfResource>still image</typeOfResouce></mods>"
      sdb = sdb_for_mods(m)
      expect(sdb.format_main_ssim).to match_array ['Image']
    end
    it 'returns empty Array and logs warning if there is no value' do
      sdb = sdb_for_mods(@mods_xml)
      expect(sdb.logger).to receive(:warn).with("#{@fake_druid} has no SearchWorks Resource Type from MODS - check <typeOfResource> and other implicated MODS elements")
      expect(sdb.format_main_ssim).to eq([])
    end
  end

  context 'title fields' do
    before(:all) do
      @title_mods = "<mods #{@ns_decl}>
      <titleInfo><title>Jerk</title><nonSort>The</nonSort><subTitle>is whom?</subTitle></titleInfo>
      <titleInfo><title>Joke</title></titleInfo>
      <titleInfo type='alternative'><title>Alternative</title></titleInfo>
      </mods>"
    end
    let :sdb do
      sdb_for_mods(@title_mods)
    end
    before(:each) do
      @title_doc_hash = sdb.doc_hash_from_mods
    end
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
        expect(@title_doc_hash[:title_245a_search]).to eq('The Jerk')
      end
      it 'title_245_search' do
        expect(@title_doc_hash[:title_245_search]).to eq('The Jerk : is whom?')
      end
      it 'title_variant_search' do
        expect(@title_doc_hash[:title_variant_search]).to match_array %w(Joke Alternative)
      end
      it 'title_related_search should not be populated from MODS' do
        expect(@title_doc_hash[:title_related_search]).to be_nil
      end
    end
    context 'display fields' do
      it 'title_display' do
        expect(@title_doc_hash[:title_display]).to eq('The Jerk : is whom?')
      end
      it 'title_245a_display' do
        expect(@title_doc_hash[:title_245a_display]).to eq('The Jerk')
      end
      it 'title_245c_display should not be populated from MODS' do
        expect(@title_doc_hash[:title_245c_display]).to be_nil
      end
      it 'title_full_display' do
        expect(@title_doc_hash[:title_full_display]).to eq('The Jerk : is whom?')
      end
      it 'removes trailing commas in title_display' do
        title_mods = "<mods #{@ns_decl}>
        <titleInfo><title>Jerk</title><nonSort>The</nonSort><subTitle>is whom,</subTitle></titleInfo>
        <titleInfo><title>Joke</title></titleInfo>
        <titleInfo type='alternative'><title>Alternative</title></titleInfo>
        </mods>"
        sdb = sdb_for_mods(title_mods)
        @title_doc_hash = sdb.doc_hash_from_mods
        @title_doc_hash
        expect(@title_doc_hash[:title_display]).to eq('The Jerk : is whom')
      end
      it 'title_variant_display should not be populated - it is a copy field' do
        expect(@title_doc_hash[:title_variant_display]).to be_nil
      end
    end
    it 'title_sort' do
      expect(@title_doc_hash[:title_sort]).to eq('Jerk is whom')
    end
  end # title fields

  context 'author fields' do
    before(:all) do
      @name_mods = "<mods #{@ns_decl}>
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
    let :sdb do
      sdb_for_mods(@name_mods)
    end
    before(:each) do
      @author_doc_hash = sdb.doc_hash_from_mods
    end
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
        expect(@author_doc_hash[:author_1xx_search]).to eq('Crusty The Clown')
      end
      it 'author_7xx_search' do
        skip 'Should this return all authors? or only 7xx authors?'
        expect(@author_doc_hash[:author_7xx_search]).to match_array ['q', 'Watchful Eye', 'Exciting Prints', 'conference']
      end
      it 'author_8xx_search should not be populated from MODS' do
        expect(@author_doc_hash[:author_8xx_search]).to be_nil
      end
    end
    context 'facet fields' do
      it 'author_person_facet' do
        expect(@author_doc_hash[:author_person_facet]).to match_array ['q', 'Crusty The Clown']
      end
      it 'author_other_facet' do
        expect(@author_doc_hash[:author_other_facet]).to match_array ['Watchful Eye', 'Exciting Prints', 'conference']
      end
    end
    context 'display fields' do
      it 'author_person_display' do
        expect(@author_doc_hash[:author_person_display]).to match_array ['q', 'Crusty The Clown']
      end
      it 'author_person_full_display' do
        expect(@author_doc_hash[:author_person_full_display]).to match_array ['q', 'Crusty The Clown']
      end
      it 'author_corp_display' do
        expect(@author_doc_hash[:author_corp_display]).to match_array ['Watchful Eye', 'Exciting Prints']
      end
      it 'author_meeting_display' do
        expect(@author_doc_hash[:author_meeting_display]).to match_array ['conference']
      end
    end
    it 'author_sort' do
      expect(@author_doc_hash[:author_sort]).to eq('Crusty The Clown')
    end
  end # author fields

  context 'subject fields' do
    before(:all) do
      @genre = 'genre top level'
      @cart_coord = '6 00 S, 71 30 E'
      @s_genre = 'genre in subject'
      @geo = 'Somewhere'
      @geo_code = 'us'
      @hier_geo_country = 'France'
      @s_name = 'name in subject'
      @occupation = 'worker bee'
      @temporal = 'temporal'
      @s_title = 'title in subject'
      @topic = 'topic'
      @m = "<mods #{@ns_decl}>
        <genre>#{@genre}</genre>
        <subject><cartographics><coordinates>#{@cart_coord}</coordinates></cartographics></subject>
        <subject><genre>#{@s_genre}</genre></subject>
        <subject><geographic>#{@geo}</geographic></subject>
        <subject><geographicCode authority='iso3166'>#{@geo_code}</geographicCode></subject>
        <subject><hierarchicalGeographic><country>#{@hier_geo_country}</country></hierarchicalGeographic></subject>
        <subject><name><namePart>#{@s_name}</namePart></name></subject>
        <subject><occupation>#{@occupation}</occupation></subject>
        <subject><temporal>#{@temporal}</temporal></subject>
        <subject><titleInfo><title>#{@s_title}</title></titleInfo></subject>
        <subject><topic>#{@topic}</topic></subject>
        <typeOfResource>still image</typeOfResource>
      </mods>"
      @m_no_subject = "<mods #{@ns_decl}><note>notit</note></mods>"
    end
    let :sdb do
      sdb = sdb_for_mods(@m)
    end
    before(:each) do
      @subject_doc_hash = sdb.doc_hash_from_mods
    end
    it 'calls the appropriate methods in stanford-mods to populate the Solr fields' do
      expect(sdb.smods_rec).to receive(:topic_search)
      expect(sdb.smods_rec).to receive(:geographic_search)
      expect(sdb.smods_rec).to receive(:subject_other_search)
      expect(sdb.smods_rec).to receive(:subject_other_subvy_search)
      expect(sdb.smods_rec).to receive(:subject_all_search)
      expect(sdb.smods_rec).to receive(:topic_facet)
      expect(sdb.smods_rec).to receive(:geographic_facet)
      expect(sdb.smods_rec).to receive(:era_facet)
      sdb.doc_hash_from_mods
    end
    context 'search fields' do
      context 'topic_search' do
        it 'onlies include genre and topic' do
          expect(@subject_doc_hash[:topic_search]).to match_array [@genre, @topic]
        end
        context 'functional tests checking results from stanford-mods methods' do
          it 'is nil if there are no values in the MODS' do
            sdb = sdb_for_mods(@m_no_subject)
            expect(sdb.doc_hash_from_mods[:topic_search]).to be_nil
          end
          it 'does not be nil if there are only subject/topic elements (no <genre>)' do
            m = "<mods #{@ns_decl}><subject><topic>#{@topic}</topic></subject></mods>"
            sdb = sdb_for_mods(m)
            expect(sdb.doc_hash_from_mods[:topic_search]).to match_array [@topic]
          end
          it 'does not be nil if there are only <genre> elements (no subject/topic elements)' do
            m = "<mods #{@ns_decl}><genre>#{@genre}</genre></mods>"
            sdb = sdb_for_mods(m)
            expect(sdb.doc_hash_from_mods[:topic_search]).to match_array [@genre]
          end
          it 'has a separate value for each topic subelement' do
            m = "<mods #{@ns_decl}>
            <subject>
              <topic>first</topic>
              <topic>second</topic>
            </subject>
            <subject><topic>third</topic></subject>
            </mods>"
            sdb = sdb_for_mods(m)
            expect(sdb.doc_hash_from_mods[:topic_search]).to match_array %w(first second third)
          end
        end # functional tests checking results from stanford-mods methods
      end # topic_search

      context 'geographic_search' do
        it 'includes geographic and hierarchicalGeographic' do
          expect(@subject_doc_hash[:geographic_search]).to match_array [@geo, @hier_geo_country]
        end
        it 'calls sw_geographic_search (from stanford-mods gem)' do
          m = "<mods #{@ns_decl}><subject><geographic>#{@geo}</geographic></subject></mods>"
          sdb = sdb_for_mods(m)
          expect(sdb.smods_rec).to receive(:sw_geographic_search).at_least(1).times
          sdb.doc_hash_from_mods
        end
        it "logs an info message when it encounters a geographicCode encoding it doesn't translate" do
          m = "<mods #{@ns_decl}><subject><geographicCode authority='iso3166'>ca</geographicCode></subject></mods>"
          sdb = sdb_for_mods(m)
          expect(sdb.smods_rec.sw_logger).to receive(:info).with(/#{@fake_druid} has subject geographicCode element with untranslated encoding \(iso3166\): <geographicCode authority=.*>ca<\/geographicCode>/).at_least(1).times
          sdb.doc_hash_from_mods
        end
      end # geographic_search

      context 'subject_other_search' do
        it 'includes occupation, subject names, and subject titles' do
          expect(@subject_doc_hash[:subject_other_search]).to match_array [@occupation, @s_name, @s_title]
        end
        context 'functional tests checking results from stanford-mods methods' do
          it 'is nil if there are no values in the MODS' do
            sdb = sdb_for_mods(@mods_xml)
            expect(sdb.doc_hash_from_mods[:subject_other_search]).to be_nil
          end
          it 'does not be nil if there are only subject/name elements' do
            m = "<mods #{@ns_decl}><subject><name><namePart>#{@s_name}</namePart></name></subject></mods>"
            sdb = sdb_for_mods(m)
            expect(sdb.doc_hash_from_mods[:subject_other_search]).to match_array [@s_name]
          end
          it 'does not be nil if there are only subject/occupation elements' do
            m = "<mods #{@ns_decl}><subject><occupation>#{@occupation}</occupation></subject></mods>"
            sdb = sdb_for_mods(m)
            expect(sdb.doc_hash_from_mods[:subject_other_search]).to match_array [@occupation]
          end
          it 'does not be nil if there are only subject/titleInfo elements' do
            m = "<mods #{@ns_decl}><subject><titleInfo><title>#{@s_title}</title></titleInfo></subject></mods>"
            sdb = sdb_for_mods(m)
            expect(sdb.doc_hash_from_mods[:subject_other_search]).to match_array [@s_title]
          end
          it 'has a separate value for each occupation subelement' do
            m = "<mods #{@ns_decl}>
            <subject>
              <occupation>first</occupation>
              <occupation>second</occupation>
            </subject>
            <subject><occupation>third</occupation></subject>
            </mods>"
            sdb = sdb_for_mods(m)
            expect(sdb.doc_hash_from_mods[:subject_other_search]).to match_array %w(first second third)
          end
        end # functional tests checking results from stanford-mods methods
      end # subject_other_search

      context 'subject_other_subvy_search' do
        it 'includes temporal and genre SUBelement' do
          expect(@subject_doc_hash[:subject_other_subvy_search]).to match_array [@temporal, @s_genre]
        end
        context 'functional tests checking results from stanford-mods methods' do
          it 'is nil if there are no values in the MODS' do
            sdb = sdb_for_mods(@mods_xml)
            expect(sdb.doc_hash_from_mods[:subject_other_subvy_search]).to be_nil
          end
          it 'does not be nil if there are only subject/temporal elements (no subject/genre)' do
            m = "<mods #{@ns_decl}><subject><temporal>#{@temporal}</temporal></subject></mods>"
            sdb = sdb_for_mods(m)
            expect(sdb.doc_hash_from_mods[:subject_other_subvy_search]).to match_array [@temporal]
          end
          it 'does not be nil if there are only subject/genre elements (no subject/temporal)' do
            m = "<mods #{@ns_decl}><subject><genre>#{@s_genre}</genre></subject></mods>"
            sdb = sdb_for_mods(m)
            expect(sdb.doc_hash_from_mods[:subject_other_subvy_search]).to match_array [@s_genre]
          end
          context 'genre subelement' do
            it 'has a separate value for each genre element' do
              m = "<mods #{@ns_decl}>
              <subject>
                <genre>first</genre>
                <genre>second</genre>
              </subject>
              <subject><genre>third</genre></subject>
              </mods>"
              sdb = sdb_for_mods(m)
              expect(sdb.doc_hash_from_mods[:subject_other_subvy_search]).to match_array %w(first second third)
            end
          end # genre subelement
        end # "functional tests checking results from stanford-mods methods"
      end # subject_other_subvy_search

      context 'subject_all_search' do
        it 'contains top level <genre> element data' do
          expect(@subject_doc_hash[:subject_all_search]).to include(@genre)
        end
        it 'does not contain cartographic sub element' do
          expect(@subject_doc_hash[:subject_all_search]).not_to include(@cart_coord)
        end
        it 'does not include codes from hierarchicalGeographic sub element' do
          expect(@subject_doc_hash[:subject_all_search]).not_to include(@geo_code)
        end
        it 'contains all other subject subelement data' do
          expect(@subject_doc_hash[:subject_all_search]).to include(@s_genre)
          expect(@subject_doc_hash[:subject_all_search]).to include(@geo)
          expect(@subject_doc_hash[:subject_all_search]).to include(@hier_geo_country)
          expect(@subject_doc_hash[:subject_all_search]).to include(@s_name)
          expect(@subject_doc_hash[:subject_all_search]).to include(@occupation)
          expect(@subject_doc_hash[:subject_all_search]).to include(@temporal)
          expect(@subject_doc_hash[:subject_all_search]).to include(@s_title)
          expect(@subject_doc_hash[:subject_all_search]).to include(@topic)
        end
      end # subject_all_search
    end # search fields

    context 'facet fields' do
      context 'topic_facet' do
        it 'includes topic subelement' do
          expect(@subject_doc_hash[:topic_facet]).to include(@topic)
        end
        it 'includes sw_subject_names' do
          expect(@subject_doc_hash[:topic_facet]).to include(@s_name)
        end
        it 'includes sw_subject_titles' do
          expect(@subject_doc_hash[:topic_facet]).to include(@s_title)
        end
        it 'includes occupation subelement' do
          expect(@subject_doc_hash[:topic_facet]).to include(@occupation)
        end
        it 'has the trailing punctuation removed' do
          m = "<mods #{@ns_decl}><subject>
          <topic>comma,</topic>
          <occupation>semicolon;</occupation>
          <titleInfo><title>backslash \\</title></titleInfo>
          <name><namePart>internal, punct;uation</namePart></name>
          </subject></mods>"
          sdb = sdb_for_mods(m)
          doc_hash = sdb.doc_hash_from_mods
          expect(doc_hash[:topic_facet]).to include('comma')
          expect(doc_hash[:topic_facet]).to include('semicolon')
          expect(doc_hash[:topic_facet]).to include('backslash')
          expect(doc_hash[:topic_facet]).to include('internal, punct;uation')
        end
      end # topic_facet

      context 'geographic_facet' do
        it 'includes geographic subelement' do
          expect(@subject_doc_hash[:geographic_facet]).to include(@geo)
        end
        it 'is like geographic_search with the trailing punctuation (and preceding spaces) removed' do
          m = "<mods #{@ns_decl}><subject>
          <geographic>comma,</geographic>
          <geographic>semicolon;</geographic>
          <geographic>backslash \\</geographic>
          <geographic>internal, punct;uation</geographic>
          </subject></mods>"
          sdb = sdb_for_mods(m)
          doc_hash = sdb.doc_hash_from_mods
          expect(doc_hash[:geographic_facet]).to include('comma')
          expect(doc_hash[:geographic_facet]).to include('semicolon')
          expect(doc_hash[:geographic_facet]).to include('backslash')
          expect(doc_hash[:geographic_facet]).to include('internal, punct;uation')
        end
      end

      it 'era_facet should be temporal subelement with the trailing punctuation removed' do
        m = "<mods #{@ns_decl}><subject>
        <temporal>comma,</temporal>
        <temporal>semicolon;</temporal>
        <temporal>backslash \\</temporal>
        <temporal>internal, punct;uation</temporal>
        </subject></mods>"
        sdb = sdb_for_mods(m)
        doc_hash = sdb.doc_hash_from_mods
        expect(doc_hash[:era_facet]).to include('comma')
        expect(doc_hash[:era_facet]).to include('semicolon')
        expect(doc_hash[:era_facet]).to include('backslash')
        expect(doc_hash[:era_facet]).to include('internal, punct;uation')
      end
    end # facet fields
  end # subject fields

  context 'publication date fields' do
    let :sdb do
      sdb = sdb_for_mods(@mods_xml)
    end

    it 'populates all date fields' do
      m = "<mods #{@ns_decl}><originInfo>
            <dateIssued>blah blah 19th century blah blah</dateIssued>
          </originInfo></mods>"
      sdb = sdb_for_mods(m)
      doc_hash = sdb.doc_hash_from_mods
      expect(doc_hash[:pub_date]).to eq('19th century')
      expect(doc_hash[:pub_date_sort]).to eq('1800')
      expect(doc_hash[:publication_year_isi]).to eq('1800')
      expect(doc_hash[:pub_year_tisim]).to eq('1800') # date slider
      expect(doc_hash[:imprint_display]).to eq('blah blah 19th century blah blah')
    end

    it 'does not populate the date slider for BC dates' do
      m = "<mods #{@ns_decl}><originInfo><dateIssued>199 B.C.</dateIssued></originInfo></mods>"
      sdb = sdb_for_mods(m)
      doc_hash = sdb.doc_hash_from_mods
      expect(doc_hash).to_not have_key(:pub_year_tisim)
    end

    context 'pub_date_sort' do
      it 'calls Stanford::Mods::Record instance pub_date_sortable_string(false)' do
        expect(sdb.smods_rec).to receive(:pub_date_sortable_string).with(false)
        sdb.doc_hash_from_mods[:pub_date_sort]
      end
      it 'yyyy for yyyy dates' do
        m = "<mods #{@ns_decl}><originInfo><dateIssued>1945</dateIssued></originInfo></mods>"
        sdb = sdb_for_mods(m)
        expect(sdb.doc_hash_from_mods[:pub_date_sort]).to eq('1945')
      end
      it '0yyy for yyy dates' do
        m = "<mods #{@ns_decl}><originInfo><dateIssued>945</dateIssued></originInfo></mods>"
        sdb = sdb_for_mods(m)
        expect(sdb.doc_hash_from_mods[:pub_date_sort]).to eq('0945')
      end
      it 'yy00 for yy-- dates' do
        m = "<mods #{@ns_decl}><originInfo><dateIssued>16--</dateIssued></originInfo></mods>"
        sdb = sdb_for_mods(m)
        expect(sdb.doc_hash_from_mods[:pub_date_sort]).to eq('1600')
      end
      it '0y00 for y-- dates' do
        m = "<mods #{@ns_decl}><originInfo><dateIssued>9--</dateIssued></originInfo></mods>"
        sdb = sdb_for_mods(m)
        expect(sdb.doc_hash_from_mods[:pub_date_sort]).to eq('0900')
      end
      it 'yy00 for yyth century dates' do
        m = "<mods #{@ns_decl}><originInfo>
              <dateIssued>19th century</dateIssued>
            </originInfo></mods>"
        sdb = sdb_for_mods(m)
        doc_hash = sdb.doc_hash_from_mods
        expect(doc_hash[:pub_date_sort]).to eq('1800')
      end
      it '0y00 for yth century dates' do
        m = "<mods #{@ns_decl}><originInfo>
              <dateIssued>9th century</dateIssued>
            </originInfo></mods>"
        sdb = sdb_for_mods(m)
        doc_hash = sdb.doc_hash_from_mods
        expect(doc_hash[:pub_date_sort]).to eq('0800')
      end
      it 'works on 3 digit BC dates' do
        m = "<mods #{@ns_decl}><originInfo>
              <dateCreated>300 B.C.</dateCreated>
            </originInfo></mods>"
        sdb = sdb_for_mods(m)
        doc_hash = sdb.doc_hash_from_mods
        expect(doc_hash[:pub_date_sort]).to eq('-700')
      end
    end # pub_date_sort

    context 'pub_year_tisim for date slider' do
      it 'takes single dateCreated' do
        m = "<mods #{@ns_decl}><originInfo>
        <dateCreated>1904</dateCreated>
        </originInfo></mods>"
        sdb = sdb_for_mods(m)
        doc_hash = sdb.doc_hash_from_mods
        expect(doc_hash[:pub_year_tisim]).to eq('1904')
      end
      it 'takes first yyyy in string' do
        m = "<mods #{@ns_decl}><originInfo>
              <dateCreated>Text dated June 4, 1594; miniatures added by 1596</dateCreated>
            </originInfo></mods>"
        sdb = sdb_for_mods(m)
        doc_hash = sdb.doc_hash_from_mods
        expect(doc_hash[:pub_year_tisim]).to eq('1594')
      end
      it 'finds year in an expanded English form' do
        m = "<mods #{@ns_decl}><originInfo>
              <dateCreated>Aug. 3rd, 1886</dateCreated>
            </originInfo></mods>"
        sdb = sdb_for_mods(m)
        doc_hash = sdb.doc_hash_from_mods
        expect(doc_hash[:pub_year_tisim]).to eq('1886')
      end
      it 'removes question marks and brackets' do
        m = "<mods #{@ns_decl}><originInfo>
              <dateCreated>Aug. 3rd, [18]86?</dateCreated>
            </originInfo></mods>"
        sdb = sdb_for_mods(m)
        doc_hash = sdb.doc_hash_from_mods
        expect(doc_hash[:pub_year_tisim]).to eq('1886')
      end
      it 'ignores an s after the decade' do
        m = "<mods #{@ns_decl}><originInfo>
              <dateCreated>early 1890s</dateCreated>
            </originInfo></mods>"
        sdb = sdb_for_mods(m)
        doc_hash = sdb.doc_hash_from_mods
        expect(doc_hash[:pub_year_tisim]).to eq('1890')
      end
      it 'takes first year from hyphenated range (for now)' do
        m = "<mods #{@ns_decl}><originInfo>
              <dateIssued>1865-6</dateIssued>
            </originInfo></mods>"
        sdb = sdb_for_mods(m)
        doc_hash = sdb.doc_hash_from_mods
        expect(doc_hash[:pub_year_tisim]).to eq('1865')
      end
    end # pub_year_tisim

    context 'difficult pub dates' do
      it 'should handle multiple pub dates (to be implemented - esp for date slider)'

      it 'handles yyth century dates' do
        m = "<mods #{@ns_decl}><originInfo>
              <dateIssued>19th century</dateIssued>
            </originInfo></mods>"
        sdb = sdb_for_mods(m)
        doc_hash = sdb.doc_hash_from_mods
        expect(doc_hash[:pub_date]).to eq('19th century')
        expect(doc_hash[:pub_date_sort]).to eq('1800')
        expect(doc_hash[:pub_year_tisim]).to eq('1800')
        expect(doc_hash[:publication_year_isi]).to eq('1800')
        expect(doc_hash[:imprint_display]).to eq('19th century')
      end

      it 'works on explicit 3 digit dates' do
        m = "<mods #{@ns_decl}><originInfo>
              <dateIssued>966</dateIssued>
            </originInfo></mods>"
        sdb = sdb_for_mods(m)
        doc_hash = sdb.doc_hash_from_mods
        expect(doc_hash[:pub_date_sort]).to eq('0966')
        expect(doc_hash[:pub_date]).to eq('966')
        expect(doc_hash[:pub_year_tisim]).to eq('0966')
        expect(doc_hash[:publication_year_isi]).to eq('0966')
        expect(doc_hash[:imprint_display]).to eq('966')
      end
      it 'works on 3 digit century dates' do
        m = "<mods #{@ns_decl}><originInfo>
              <dateIssued>9th century</dateIssued>
            </originInfo></mods>"
        sdb = sdb_for_mods(m)
        doc_hash = sdb.doc_hash_from_mods
        expect(doc_hash[:pub_date_sort]).to eq('0800')
        expect(doc_hash[:pub_year_tisim]).to eq('0800')
        expect(doc_hash[:pub_date]).to eq('9th century')
        expect(doc_hash[:publication_year_isi]).to eq('0800')
        expect(doc_hash[:imprint_display]).to eq('9th century')
      end
      it 'works on 3 digit BC dates' do
        m = "<mods #{@ns_decl}><originInfo>
              <dateCreated>300 B.C.</dateCreated>
            </originInfo></mods>"
        sdb = sdb_for_mods(m)
        doc_hash = sdb.doc_hash_from_mods
        expect(doc_hash[:pub_date_sort]).to eq('-700')
        expect(doc_hash[:pub_year_tisim]).to be_nil
        expect(doc_hash[:pub_date]).to eq('300 B.C.')
        expect(doc_hash[:imprint_display]).to eq('300 B.C.')
        # doc_hash[:creation_year_isi].should =='-300'
      end
    end # difficult pub dates
  end # publication date fields
end
