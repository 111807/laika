class TestType
  attr_reader :name
  attr_accessor :assign_cb

  class AssignFailure < StandardError; end

  def initialize(name, &block)
    @name = name
    Registration.new(self, &block)
  end

  # Get all of the registered test types.
  def self.all
    test_types.values
  end

  # Get the names of all of the registered test types.
  def self.names
    test_types.values.map(&:name)
  end

  # Get a registered test type given a name.
  # If there is no such test registered, returns nil.
  def self.get(type_name)
    test_types[ normalize_name(type_name) ]
  end

  # Register a new type type by passing a name and a Registration block.
  def self.register(name, &block)
    test_types[ normalize_name(name) ] = new(name, &block)
  end

  # Assign a test, must pass a hash containing:
  # :patient, :user, :vendor
  def assign(opt)
    raise 'patient required' if not opt.key?(:patient)
    raise 'user required'    if not opt.key?(:user)
    raise 'vendor required'  if not opt.key?(:vendor)

    patient = nil

    begin
      Patient.transaction do
        # XXX currently still requires identically-named kinds in the database
        kind = Kind.find_by_display_name(name) || raise("No kind named #{name}")

        patient = opt[:patient].clone
        patient.create_vendor_test_plan(
          :vendor => opt[:vendor],
          :user   => opt[:user],
          :kind   => kind
        )
  
        if assign_cb
          begin
            assign_cb.call(patient.vendor_test_plan) if assign_cb
          rescue RuntimeError => e
            raise AssignFailure, %{
              Failed during assignment callback: #{e}
            }
          end
        end
  
        patient.vendor_test_plan.save!
        patient.save!
      end
    rescue ActiveRecord::RecordInvalid => e
      # FIXME should be using record.class.human_name but
      # https://rails.lighthouseapp.com/projects/8994/tickets/2120
      raise AssignFailure, %{
        Failed to create #{e.record.class.name.underscore.humanize}:
        #{e.record.errors.full_messages.join("\n")}
      }
    end

    patient.vendor_test_plan
  end

  # Manage test type registration
  class Registration
    def initialize(test_type, &block)
      @test_type = test_type
      instance_eval(&block) if block_given?
    end

    def assign(&block)
      @test_type.assign_cb = block
    end
  end

  private

  def self.test_types
    @test_types ||= {}
  end

  def self.normalize_name(name)
    name.strip.downcase.gsub(/\ba?nd?\b|&/i, '-').gsub(/\W+/, '-')
  end
end