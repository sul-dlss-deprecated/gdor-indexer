require 'spec_helper'
# FIXME:  should all these be required, chain-wise, in Indexer class?
require 'mods_fields'

describe 'mods_fields mixin for SolrDocBuilder class' do

  before(:all) do
    @fake_druid = 'oo000oo0000'
    @ns_decl = "xmlns='#{Mods::MODS_NS}'"
  end
  
  before(:each) do
    @hdor_client = double()
    @hdor_client.stub(:public_xml).with(@fake_druid).and_return(nil)
  end

  context "sw subject methods" do
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
      m = "<mods #{@ns_decl}>
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
      </mods>"
      @ng_mods = Nokogiri::XML(m)
      m_no_subject = "<mods #{@ns_decl}><note>notit</note></mods>"
      @ng_mods_no_subject = Nokogiri::XML(m_no_subject)
    end
    before(:each) do
      @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods)      
      @sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
    end
    
    context "topic_search" do
      it "should be nil if there are no values in the MODS" do
        @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_no_subject)
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
        sdb.topic_search.should == nil
      end
      it "should contain subject <topic> subelement data" do
        @sdb.topic_search.should include(@topic)
      end
      it "should contain <genre> element data" do
        @sdb.topic_search.should include(@genre)
      end
      it "should not contain other subject element data" do
        @sdb.topic_search.should_not include(@cart_coord)
        @sdb.topic_search.should_not include(@s_genre)
        @sdb.topic_search.should_not include(@geo)
        @sdb.topic_search.should_not include(@geo_code)
        @sdb.topic_search.should_not include(@hier_geo_country)
        @sdb.topic_search.should_not include(@s_name)
        @sdb.topic_search.should_not include(@occupation)
        @sdb.topic_search.should_not include(@temporal)
        @sdb.topic_search.should_not include(@s_title)
      end
      it "should not be nil if there are only subject/topic elements (no <genre>)" do
        m = "<mods #{@ns_decl}><subject><topic>#{@topic}</topic></subject></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
        sdb.topic_search.should == [@topic]
      end
      it "should not be nil if there are only <genre> elements (no subject/topic elements)" do
        m = "<mods #{@ns_decl}><genre>#{@genre}</genre></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
        sdb.topic_search.should == [@genre]
      end
      context "topic subelement" do
        it "should have a separate value for each topic element" do
          m = "<mods #{@ns_decl}>
                <subject>
                  <topic>first</topic>
                  <topic>second</topic>
                </subject>
                <subject><topic>third</topic></subject>
              </mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
          sdb.topic_search.should == ['first', 'second', 'third']
        end
        it "should be nil if there are only empty values in the MODS" do
          m = "<mods #{@ns_decl}><subject><topic/></subject><note>notit</note></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
          sdb.topic_search.should == nil
        end
      end
    end # topic_search
    
    context "geographic_search" do
      it "should be nil if there are no values in the MODS" do
        @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_no_subject)
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
        sdb.geographic_search.should == nil
      end
      it "should contain subject <geographic> subelement data" do
        @sdb.geographic_search.should include(@geo)
      end
      it "should contain subject <hierarchicalGeographic> subelement data" do
        @sdb.geographic_search.should include(@hier_geo_country)
      end
      it "should contain translation of <geographicCode> subelement data with translated authorities" do
        m = "<mods #{@ns_decl}><subject><geographicCode authority='marcgac'>e-er</geographicCode></subject></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
        sdb.geographic_search.should include('Estonia')
      end
      it "should not contain other subject element data" do
        @sdb.geographic_search.should_not include(@genre)
        @sdb.geographic_search.should_not include(@cart_coord)
        @sdb.geographic_search.should_not include(@s_genre)
        @sdb.geographic_search.should_not include(@s_name)
        @sdb.geographic_search.should_not include(@occupation)
        @sdb.geographic_search.should_not include(@temporal)
        @sdb.geographic_search.should_not include(@topic)
        @sdb.geographic_search.should_not include(@s_title)
      end
      it "should not be nil if there are only subject/geographic elements" do
        m = "<mods #{@ns_decl}><subject><geographic>#{@geo}</geographic></subject></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
        sdb.geographic_search.should == [@geo]
      end
      it "should not be nil if there are only subject/hierarchicalGeographic" do
        m = "<mods #{@ns_decl}><subject><hierarchicalGeographic>#{@hier_geo_country}</hierarchicalGeographic></subject></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
        sdb.geographic_search.should == [@hier_geo_country]
      end
      it "should not be nil if there are only subject/geographicCode elements" do
        m = "<mods #{@ns_decl}><subject><geographicCode authority='marcgac'>e-er</geographicCode></subject></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
        sdb.geographic_search.should == ['Estonia']
      end
      context "geographic subelement" do
        it "should have a separate value for each geographic element" do
          m = "<mods #{@ns_decl}>
                <subject>
                <geographic>Mississippi</geographic>
                <geographic>Tippah County</geographic>
                </subject>
                <subject><geographic>Washington (D.C.)</geographic></subject>
              </mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
          sdb.geographic_search.should == ['Mississippi', 'Tippah County', 'Washington (D.C.)']
        end
        it "should be nil if there are only empty values in the MODS" do
          m = "<mods #{@ns_decl}><subject><geographic/></subject><note>notit</note></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
          sdb.geographic_search.should == nil
        end
      end
      context "hierarchicalGeographic subelement" do
        before(:all) do
          m = "<mods #{@ns_decl}>
          <subject>
            <hierarchicalGeographic>
            	<country>Canada</country>
            	<province>British Columbia</province>
            	<city>Vancouver</city>
            </hierarchicalGeographic>
          </subject>
          <subject>
          	<hierarchicalGeographic>
        	  	<country>France</country>
        	  	<state>Doubs</state>
          	</hierarchicalGeographic>
          </subject>
          <subject>
          	<hierarchicalGeographic>
        	  	<country>France</country>
        	  	<region>Franche Comte</region>
          	</hierarchicalGeographic>
          </subject>        
          <subject>
          	<hierarchicalGeographic>
        	  	<country>United States</country>
        	  	<state>Kansas</state>
        	  	<county>Butler</county>
        	  	<city>Augusta</city>
          	</hierarchicalGeographic>
          </subject>
          <subject>
          	<hierarchicalGeographic>
        	  	<area>Intercontinental areas (Western Hemisphere)</area>
          	</hierarchicalGeographic>
          </subject>
          </mods>"
        end
        # sub elements!  should be cat together into a single value???
        it "should do something sensible with the hierarchical information (sort of lcsh-ish?)" do
          pending "to be implemented"
        end
        it "should have a separate value for each hierarchicalGeographic element" do
          m = "<mods #{@ns_decl}>
                <subject>
                  <hierarchicalGeographic>first</hierarchicalGeographic>
                  <hierarchicalGeographic>second</hierarchicalGeographic>
                </subject>
                <subject><hierarchicalGeographic>third</hierarchicalGeographic></subject>
              </mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
          sdb.geographic_search.should == ['first', 'second', 'third']
        end
        it "should be nil if there are only empty values in the MODS" do
          m = "<mods #{@ns_decl}><subject><hierarchicalGeographic/></subject><note>notit</note></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
          sdb.geographic_search.should == nil
        end
      end
      context "geographicCode subelement" do
        before(:all) do
          @mods = "<mods #{@ns_decl}>
            <subject><geographicCode authority='marcgac'>n-us-md</geographicCode></subject>
            <subject><geographicCode authority='marcgac'>e-er</geographicCode></subject>
            <subject><geographicCode authority='marccountry'>mg</geographicCode></subject>
            <subject><geographicCode authority='iso3166'>us</geographicCode></subject>
          </mods>"
        end
        before(:each) do
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(@mods))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
          @geo_search_from_codes = sdb.geographic_search
        end
        it "should not add untranslated values" do
          @geo_search_from_codes.should_not include('n-us-md')
          @geo_search_from_codes.should_not include('e-er')
          @geo_search_from_codes.should_not include('mg')
          @geo_search_from_codes.should_not include('us')
        end
        it "should translate marcgac codes" do
          @geo_search_from_codes.should include('Estonia')
        end
        it "should translate marccountry codes" do
          @geo_search_from_codes.should include('Madagascar')
        end
        it "should not translate other codes" do
          @geo_search_from_codes.should_not include('United States')
        end
        it "should have a separate value for each geographicCode element" do
          m = "<mods #{@ns_decl}>
                <subject>
                  <geographicCode authority='marcgac'>e-er</geographicCode>
                	<geographicCode authority='marccountry'>mg</geographicCode>
                </subject>
                <subject><geographicCode authority='marcgac'>n-us-md</geographicCode></subject>
              </mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
          sdb.geographic_search.should == ['Estonia', 'Madagascar', 'Maryland']
        end
        it "should be nil if there are only empty values in the MODS" do
          m = "<mods #{@ns_decl}><subject><geographicCode/></subject><note>notit</note></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
          sdb.geographic_search.should == nil
        end
        it "should add the translated value if it wasn't present already" do
          m = "<mods #{@ns_decl}>
            <subject><geographic>Somewhere</geographic></subject>
            <subject><geographicCode authority='marcgac'>e-er</geographicCode></subject>
          </mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
          sdb.geographic_search.size.should == 2
          sdb.geographic_search.should include('Estonia')
        end
        it "should not add the translated value if it was already present" do
          m = "<mods #{@ns_decl}>
            <subject><geographic>Estonia</geographic></subject>
            <subject><geographicCode authority='marcgac'>e-er</geographicCode></subject>
          </mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
          sdb.geographic_search.size.should == 1
          sdb.geographic_search.should == ['Estonia']
        end
        it "should log an info message when it encounters an encoding it doesn't translate" do
          m = "<mods #{@ns_decl}><subject><geographicCode authority='iso3166'>ca</geographicCode></subject></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
          sdb.logger.should_receive(:info).with(/#{@fake_druid} has subject geographicCode element with untranslated encoding \(iso3166\): <geographicCode authority=.*>ca<\/geographicCode>/)
          sdb.geographic_search
        end
      end
    end # geographic_search

    context "subject_other_subvy_search" do
      it "should be nil if there are no values in the MODS" do
        @hdor_client.stub(:mods).with(@fake_druid).and_return(@ng_mods_no_subject)
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
        sdb.subject_other_subvy_search.should == nil
      end
      it "should contain subject <temporal> subelement data" do
        @sdb.subject_other_subvy_search.should include(@temporal)
      end
      it "should contain subject <genre> SUBelement data" do
        @sdb.subject_other_subvy_search.should include(@s_genre)
      end
      it "should not contain other subject element data" do
        @sdb.subject_other_subvy_search.should_not include(@genre)
        @sdb.subject_other_subvy_search.should_not include(@cart_coord)
        @sdb.subject_other_subvy_search.should_not include(@geo)
        @sdb.subject_other_subvy_search.should_not include(@geo_code)
        @sdb.subject_other_subvy_search.should_not include(@hier_geo_country)
        @sdb.subject_other_subvy_search.should_not include(@s_name)
        @sdb.subject_other_subvy_search.should_not include(@occupation)
        @sdb.subject_other_subvy_search.should_not include(@topic)
        @sdb.subject_other_subvy_search.should_not include(@s_title)
      end
      it "should not be nil if there are only subject/temporal elements (no subject/genre)" do
        m = "<mods #{@ns_decl}><subject><temporal>#{@temporal}</temporal></subject></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
        sdb.subject_other_subvy_search.should == [@temporal]
      end
      it "should not be nil if there are only subject/genre elements (no subject/temporal)" do
        m = "<mods #{@ns_decl}><subject><genre>#{@s_genre}</genre></subject></mods>"
        @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
        sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
        sdb.subject_other_subvy_search.should == [@s_genre]
      end
      context "temporal subelement" do
        it "should have a separate value for each temporal element" do
          m = "<mods #{@ns_decl}>
                <subject>
                  <temporal>1890-1910</temporal>
                	<temporal>20th century</temporal>
                </subject>
                <subject><temporal>another</temporal></subject>
              </mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
          sdb.subject_other_subvy_search.should == ['1890-1910', '20th century', 'another']
        end
        it "should log an info message when it encounters an encoding it doesn't translate" do
          m = "<mods #{@ns_decl}><subject><temporal encoding='iso8601'>197505</temporal></subject></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
          sdb.logger.should_receive(:info).with(/#{@fake_druid} has subject temporal element with untranslated encoding: <temporal encoding=.*>197505<\/temporal>/)
          sdb.subject_other_subvy_search
        end
        it "should be nil if there are only empty values in the MODS" do
          m = "<mods #{@ns_decl}><subject><temporal/></subject><note>notit</note></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
          sdb.subject_other_subvy_search.should == nil
        end
      end
      context "genre subelement" do
        it "should have a separate value for each genre element" do
          m = "<mods #{@ns_decl}>
                <subject>
                  <genre>first</genre>
                  <genre>second</genre>
                </subject>
                <subject><genre>third</genre></subject>
              </mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
          sdb.subject_other_subvy_search.should == ['first', 'second', 'third']
        end
        it "should be nil if there are only empty values in the MODS" do
          m = "<mods #{@ns_decl}><subject><genre/></subject><note>notit</note></mods>"
          @hdor_client.stub(:mods).with(@fake_druid).and_return(Nokogiri::XML(m))
          sdb = SolrDocBuilder.new(@fake_druid, @hdor_client, Logger.new(STDOUT))
          sdb.subject_other_subvy_search.should == nil
        end
      end
    end # subject_other_subvy_search


    context "topic" do
      before(:all) do
        m = "<mods #{@ns_decl}>
        <subject authority='lcsh'>
          <topic>Real property</topic>
          <geographic>Mississippi</geographic>
          <geographic>Tippah County</geographic>
          <genre>Maps</genre>
        </subject>
        <subject authority='lcsh'>
          <topic>Musicology</topic>
          <topic>Data processing</topic>
          <genre>Periodicals</genre>
        </subject>
        <subject authority='lcsh'>
          <topic>Real property--Mississippi--Tippah County--Maps</topic>
        </subject>
        <subject authority='lcshac'>
          <topic>Iron founding</topic>
        </subject>
        <subject authority='lctgm'>
        	<topic>Educational buildings</topic>
        	<geographic>Washington (D.C.)</geographic>
        	<temporal>1890-1910</temporal>
        </subject>
        <subject>
          <occupation>Migrant laborers</occupation>
          <genre>School district case files</genre>
        </subject>
        <subject authority='ericd'>
        	<topic>Career Exploration</topic>
        </subject>
        <subject authority='rvm'>
        	<topic>Eglise catholique</topic>
        	<topic>Histoire</topic>
        	<temporal>20e siecle</temporal>
        </subject>
        <subject>
        	<topic>Learning disabilities</topic>
        </subject>
        <subject>
        	<name type='personal' authority='naf'>
      	  	<namePart>Woolf, Virginia</namePart>
      	  	<namePart type='date'>1882-1941</namePart>
        	</name>
        </subject>
        <subject authority='lcsh'>
         	<name>
         	  <namePart>Garcia Lorca, Federico</namePart>
          	<namePart type='date'>1898-1936</namePart>
          </name>
        </subject>
        <subject>
        	<occupation>Anthropologists</occupation>
        </subject>
        <subject>
        	<titleInfo type='uniform' authority='naf'>
      	  	<title>Missale Carnotense</title>
        	</titleInfo>
        </subject>
        <subject>
        	<temporal encoding='iso8601'>197505</temporal>
        </subject>
        </mods>"
      end
    end # topic
    
  end # context sw subject methods
  
  
end