class AdvanceDirective < ActiveRecord::Base

  strip_attributes!

  belongs_to :patient_data  
  belongs_to :advance_directive_type
  belongs_to :advance_directive_status_code

  include PersonLike
  include MatchHelper

  @@default_namespaces = {"cda"=>"urn:hl7-org:v3"}

  def requirements
    {
      :advance_directive_type_id => :hitsp_r2_required,
      :free_text => :hitsp_required,
      :start_effective_time => :hitsp_optional,
      :end_effective_time => :hitsp_optional,
      :advance_directive_status_code_id => :required,
    }
  end

  def validate_c32(document)

    errors = []

    begin
      section = REXML::XPath.first(document,"//cda:section[cda:templateId/@root='2.16.840.1.113883.10.20.1.1']",@@default_namespaces)
      if section
        observation = REXML::XPath.first(section,"cda:entry/cda:observation[cda:templateId/@root='2.16.840.1.113883.10.20.1.17']",@@default_namespaces)
        # match person type info
        entity = REXML::XPath.first(observation,"cda:participant[@typeCode='CST']/cda:participantRole[@classCode='AGNT']",@@default_namespaces)
        code = REXML::XPath.first(observation,"cda:code",@@default_namespaces)
        text =  REXML::XPath.first(code,"cda:originalText",@@default_namespaces)
        deref_text = deref(text)

        if advance_directive_type
          errors.concat advance_directive_type.validate_c32(code)
        end

        if(deref_text != free_text)
          errors << ContentError.new(:section=>"Advance Directive",
                                     :error_message=>"Directive text #{free_text} does not match #{deref_text}",
                                     :location=>(text)? text.xpath : (code)? code.xpath : section.xpath )
        end
        if person_name
          errors.concat person_name.validate_c32(REXML::XPath.first(entity,'cda:playingEntity/cda:name',@@default_namespaces))
        end
        if address
          errors.concat address.validate_c32(REXML::XPath.first(entity,'cda:addr',@@default_namespaces))
        end
        if telecom
          errors.concat telecom.validate_c32(entity)
        end
      else
          errors << ContentError.new(:section => 'Advance Directive', 
                                    :error_message => 'Advance Directive not found in document',
                                    :type=>'error',
                                    :location => document.xpath)          
      end
    rescue
      errors << ContentError.new(:section => 'Advance Directive', 
                                 :error_message => 'Invalid, non-parsable XML for advance directive data',
                                 :type=>'error',
                                 :location => document.xpath)
    end

    errors.compact

  end

  def to_c32(xml)

    xml.component do
      xml.section do
        xml.templateId("root" => "2.16.840.1.113883.10.20.1.1")
        xml.code("code" => "42348-3", 
                 "codeSystem" => "2.16.840.1.113883.6.1", 
                 "codeSystemName" => "LOINC")
        xml.title "Advance Directive"
        xml.text do
          xml.content(free_text, "ID" => "advance-directive-" + id.to_s)
        end

        xml.entry do
          xml.observation("classCode" => "OBS", "moodCode" => "EVN") do
            xml.templateId("root" => "2.16.840.1.113883.10.20.1.17", "assigningAuthorityName" => "CCD")
            xml.templateId("root" => "2.16.840.1.113883.3.88.11.32.13", "assigningAuthorityName" => "HITSP/C32")
            xml.id
            if advance_directive_type
              xml.code("code" => advance_directive_type.code, 
                       "displayName" => advance_directive_type.name, 
                       "codeSystem" => "2.16.840.1.113883.6.96",
                       "codeSystemName" => "SNOMED CT") do
                xml.originalText do
                  xml.reference("value" => "advance-directive-" + id.to_s)
                end
              end
            end 

            xml.statusCode("code" => "completed")

            if start_effective_time != nil || start_effective_time != nil
              xml.effectiveTime do
                if start_effective_time != nil 
                  xml.low("value" => start_effective_time.strftime("%Y%m%d"))
                end
                if end_effective_time != nil
                  xml.high("value" => end_effective_time.strftime("%Y%m%d"))
                else
                  xml.high("nullFlavor" => "UNK")
                end
              end
            end

            xml.participant("typeCode" => "CST") do
              xml.participantRole("classCode" => "AGNT") do
                address.andand.to_c32(xml)
                telecom.andand.to_c32(xml) 
                xml.playingEntity do
                  person_name.andand.to_c32(xml)
                end
              end
            end

            if advance_directive_status_code
              xml.entryRelationship("typeCode" => "REFR") do
                xml.observation("classCode" => "OBS", "moodCode" => "EVN") do
                  xml.templateId("root" => "2.16.840.1.113883.10.20.1.37")
                  xml.code("code" => "33999-4", 
                           "codeSystem"=>"2.16.840.1.113883.6.1", 
                           "displayName" => "Status")
                  xml.statusCode('code' => "completed")
                  xml.value("xsi:type" => "CE", 
                            "code" => advance_directive_status_code.code, 
                            "codeSystem" => "2.16.840.1.113883.6.96", 
                            "displayName" => advance_directive_status_code.name)
                end
              end
            end
          end
        end
      end
    end

  end

  def randomize(birth_date)
    self.address = Address.new
    self.person_name = PersonName.new
    self.telecom = Telecom.new

    self.person_name.first_name = Faker::Name.first_name
    self.person_name.last_name = Faker::Name.last_name
    self.advance_directive_type = AdvanceDirectiveType.find(:all).sort_by {rand}.first
    self.advance_directive_status_code = AdvanceDirectiveStatusCode.find(:all).sort_by {rand}.first
    self.free_text = "Do not give " + self.advance_directive_type.name
    self.address.randomize()
    self.telecom.randomize()
    self.start_effective_time = DateTime.new(birth_date.year + rand(DateTime.now.year - birth_date.year), rand(12) + 1, rand(28) +1)
  end

  private 

  def deref(code)
    if code
      ref = REXML::XPath.first(code,"cda:reference",@@default_namespaces)
      if ref
        REXML::XPath.first(code.document,"//cda:content[@ID=$id]/text()",@@default_namespaces,{"id"=>ref.attributes['value'].gsub("#",'')}) 
      else
        nil
      end
    end 
  end

end
