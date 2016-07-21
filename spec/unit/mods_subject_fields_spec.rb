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

  context 'subject fields' do
    let(:genre) { 'genre top level' }
    let(:cart_coord) { '6 00 S, 71 30 E' }
    let(:s_genre) { 'genre in subject' }
    let(:geo) { 'Somewhere' }
    let(:geo_code) { 'us' }
    let(:hier_geo_country) { 'France' }
    let(:s_name) { 'name in subject' }
    let(:occupation) { 'worker bee' }
    let(:temporal) { 'temporal' }
    let(:s_title) { 'title in subject' }
    let(:topic) { 'topic' }
    let(:m) do
      "<mods #{ns_decl}>
        <genre>#{genre}</genre>
        <subject><cartographics><coordinates>#{cart_coord}</coordinates></cartographics></subject>
        <subject><genre>#{s_genre}</genre></subject>
        <subject><geographic>#{geo}</geographic></subject>
        <subject><geographicCode authority='iso3166'>#{geo_code}</geographicCode></subject>
        <subject><hierarchicalGeographic><country>#{hier_geo_country}</country></hierarchicalGeographic></subject>
        <subject><name><namePart>#{s_name}</namePart></name></subject>
        <subject><occupation>#{occupation}</occupation></subject>
        <subject><temporal>#{temporal}</temporal></subject>
        <subject><titleInfo><title>#{s_title}</title></titleInfo></subject>
        <subject><topic>#{topic}</topic></subject>
        <typeOfResource>still image</typeOfResource>
      </mods>"
    end
    let(:m_no_subject) { "<mods #{ns_decl}><note>notit</note></mods>" }
    let(:sdb) { sdb_for_mods(m) }
    let(:subject_doc_hash) { sdb.doc_hash_from_mods }

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
          expect(subject_doc_hash[:topic_search]).to match_array [genre, topic]
        end
        context 'functional tests checking results from stanford-mods methods' do
          it 'is nil if there are no values in the MODS' do
            sdb = sdb_for_mods(m_no_subject)
            expect(sdb.doc_hash_from_mods[:topic_search]).to be_nil
          end
          it 'does not be nil if there are only subject/topic elements (no <genre>)' do
            m = "<mods #{ns_decl}><subject><topic>#{topic}</topic></subject></mods>"
            sdb = sdb_for_mods(m)
            expect(sdb.doc_hash_from_mods[:topic_search]).to match_array [topic]
          end
          it 'does not be nil if there are only <genre> elements (no subject/topic elements)' do
            m = "<mods #{ns_decl}><genre>#{genre}</genre></mods>"
            sdb = sdb_for_mods(m)
            expect(sdb.doc_hash_from_mods[:topic_search]).to match_array [genre]
          end
          it 'has a separate value for each topic subelement' do
            m = "<mods #{ns_decl}>
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
          expect(subject_doc_hash[:geographic_search]).to match_array [geo, hier_geo_country]
        end
        it 'calls sw_geographic_search (from stanford-mods gem)' do
          m = "<mods #{ns_decl}><subject><geographic>#{geo}</geographic></subject></mods>"
          sdb = sdb_for_mods(m)
          expect(sdb.smods_rec).to receive(:sw_geographic_search).at_least(1).times
          sdb.doc_hash_from_mods
        end
        it "logs an info message when it encounters a geographicCode encoding it doesn't translate" do
          m = "<mods #{ns_decl}><subject><geographicCode authority='iso3166'>ca</geographicCode></subject></mods>"
          sdb = sdb_for_mods(m)
          expect(sdb.smods_rec.sw_logger).to receive(:info).with(/#{fake_druid} has subject geographicCode element with untranslated encoding \(iso3166\): <geographicCode authority=.*>ca<\/geographicCode>/).at_least(1).times
          sdb.doc_hash_from_mods
        end
      end # geographic_search

      context 'subject_other_search' do
        it 'includes occupation, subject names, and subject titles' do
          expect(subject_doc_hash[:subject_other_search]).to match_array [occupation, s_name, s_title]
        end
        context 'functional tests checking results from stanford-mods methods' do
          it 'is nil if there are no values in the MODS' do
            sdb = sdb_for_mods(mods_xml)
            expect(sdb.doc_hash_from_mods[:subject_other_search]).to be_nil
          end
          it 'does not be nil if there are only subject/name elements' do
            m = "<mods #{ns_decl}><subject><name><namePart>#{s_name}</namePart></name></subject></mods>"
            sdb = sdb_for_mods(m)
            expect(sdb.doc_hash_from_mods[:subject_other_search]).to match_array [s_name]
          end
          it 'does not be nil if there are only subject/occupation elements' do
            m = "<mods #{ns_decl}><subject><occupation>#{occupation}</occupation></subject></mods>"
            sdb = sdb_for_mods(m)
            expect(sdb.doc_hash_from_mods[:subject_other_search]).to match_array [occupation]
          end
          it 'does not be nil if there are only subject/titleInfo elements' do
            m = "<mods #{ns_decl}><subject><titleInfo><title>#{s_title}</title></titleInfo></subject></mods>"
            sdb = sdb_for_mods(m)
            expect(sdb.doc_hash_from_mods[:subject_other_search]).to match_array [s_title]
          end
          it 'has a separate value for each occupation subelement' do
            m = "<mods #{ns_decl}>
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
          expect(subject_doc_hash[:subject_other_subvy_search]).to match_array [temporal, s_genre]
        end
        context 'functional tests checking results from stanford-mods methods' do
          it 'is nil if there are no values in the MODS' do
            sdb = sdb_for_mods(mods_xml)
            expect(sdb.doc_hash_from_mods[:subject_other_subvy_search]).to be_nil
          end
          it 'does not be nil if there are only subject/temporal elements (no subject/genre)' do
            m = "<mods #{ns_decl}><subject><temporal>#{temporal}</temporal></subject></mods>"
            sdb = sdb_for_mods(m)
            expect(sdb.doc_hash_from_mods[:subject_other_subvy_search]).to match_array [temporal]
          end
          it 'does not be nil if there are only subject/genre elements (no subject/temporal)' do
            m = "<mods #{ns_decl}><subject><genre>#{s_genre}</genre></subject></mods>"
            sdb = sdb_for_mods(m)
            expect(sdb.doc_hash_from_mods[:subject_other_subvy_search]).to match_array [s_genre]
          end
          context 'genre subelement' do
            it 'has a separate value for each genre element' do
              m = "<mods #{ns_decl}>
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
          expect(subject_doc_hash[:subject_all_search]).to include(genre)
        end
        it 'does not contain cartographic sub element' do
          expect(subject_doc_hash[:subject_all_search]).not_to include(cart_coord)
        end
        it 'does not include codes from hierarchicalGeographic sub element' do
          expect(subject_doc_hash[:subject_all_search]).not_to include(geo_code)
        end
        it 'contains all other subject subelement data' do
          expect(subject_doc_hash[:subject_all_search]).to include(s_genre)
          expect(subject_doc_hash[:subject_all_search]).to include(geo)
          expect(subject_doc_hash[:subject_all_search]).to include(hier_geo_country)
          expect(subject_doc_hash[:subject_all_search]).to include(s_name)
          expect(subject_doc_hash[:subject_all_search]).to include(occupation)
          expect(subject_doc_hash[:subject_all_search]).to include(temporal)
          expect(subject_doc_hash[:subject_all_search]).to include(s_title)
          expect(subject_doc_hash[:subject_all_search]).to include(topic)
        end
      end # subject_all_search
    end # search fields

    context 'facet fields' do
      context 'topic_facet' do
        it 'includes topic subelement' do
          expect(subject_doc_hash[:topic_facet]).to include(topic)
        end
        it 'includes sw_subject_names' do
          expect(subject_doc_hash[:topic_facet]).to include(s_name)
        end
        it 'includes sw_subject_titles' do
          expect(subject_doc_hash[:topic_facet]).to include(s_title)
        end
        it 'includes occupation subelement' do
          expect(subject_doc_hash[:topic_facet]).to include(occupation)
        end
        it 'has the trailing punctuation removed' do
          m = "<mods #{ns_decl}><subject>
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
          expect(subject_doc_hash[:geographic_facet]).to include(geo)
        end
        it 'is like geographic_search with the trailing punctuation (and preceding spaces) removed' do
          m = "<mods #{ns_decl}><subject>
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
        m = "<mods #{ns_decl}><subject>
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

  # publication fields moved to mods_pub_fields_spec.rb
end
