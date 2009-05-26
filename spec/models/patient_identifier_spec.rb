require File.dirname(__FILE__) + '/../spec_helper'

describe PatientIdentifier do
  fixtures :patient_identifiers

  describe "testing patient identifier to patient" do
    before(:each) do
      @patient_id = patient_identifiers(:pixfeed)
    end

    # XXX this doesn't test anything, it just verifies the contents of the fixture
    it "is valid" do
      @patient_id.patient_identifier.should == '1234567890'
      @patient_id.affinity_domain.should == 'CCHIT&1.2.3.4.5.6.7.8.9&ISO'
    end

    it "should assemble an identifier string" do
      @patient_id.identifier_and_domain.should == '1234567890^^^CCHIT&1.2.3.4.5.6.7.8.9&ISO'
    end

  end
end
