# frozen_string_literal: true

require_relative './data_absent_reason_checker'
require_relative './profile_definitions/us_core_location_definitions'

module Inferno
  module Sequence
    class USCore310LocationSequence < SequenceBase
      include Inferno::DataAbsentReasonChecker
      include Inferno::USCore310ProfileDefinitions

      title 'Location'

      description 'Verify that Location resources on the FHIR server follow the US Core Implementation Guide'

      details %(
        # Background

        The US Core #{title} sequence looks to see if the selected FHIR server is able to serve `#{title.gsub(/\s+/, '')}` resources
        while following the US Core Implementation Guide.

        # Testing Methodology


        Because Location resources do not exist in USCDI, no searches are performed on this test sequence. Instead, references to
        this profile found in other resources are used for testing. If no references can be found this way, then all the tests
        in this sequence are skipped.

        ## Must Support
        Each profile has a list of elements marked as "must support". This test sequence expects to see each of these elements
        at least once. If at least one cannot be found, the test will fail. The test will look through the `#{title.gsub(/\s+/, '')}`
        resources found for these elements.

        ## Profile Validation
        Each resource returned from the first search is expected to conform to the (US Core profile)[http://hl7.org/fhir/us/core/StructureDefinition/us-core-location].
        Each element is checked against teminology binding and cardinality requirements.

        Elements with a required binding is validated against its bound valueset. If the code/system in the element is not part
        of the valueset, then the test will fail.

        ## Reference Validation
        Each reference within the resources found from the first search must resolve. The test will attempt to read each reference found
        and will fail if any attempted read fails.
      )

      test_id_prefix 'USCL'

      requires :token
      conformance_supports :Location
      delayed_sequence

      def validate_resource_item(resource, property, value)
        case property

        when 'name'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'name') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'name on resource does not match name requested'

        when 'address'
          value_found = resolve_element_from_path(resource, 'address') do |address|
            address&.text&.start_with?(value) ||
              address&.city&.start_with?(value) ||
              address&.state&.start_with?(value) ||
              address&.postalCode&.start_with?(value) ||
              address&.country&.start_with?(value)
          end
          assert value_found.present?, 'address on resource does not match address requested'

        when 'address-city'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'address.city') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'address-city on resource does not match address-city requested'

        when 'address-state'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'address.state') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'address-state on resource does not match address-state requested'

        when 'address-postalcode'
          values = value.split(/(?<!\\),/).each { |str| str.gsub!('\,', ',') }
          value_found = resolve_element_from_path(resource, 'address.postalCode') { |value_in_resource| values.include? value_in_resource }
          assert value_found.present?, 'address-postalcode on resource does not match address-postalcode requested'

        end
      end

      def patient_ids
        @instance.patient_ids.split(',').map(&:strip)
      end

      @resources_found = false

      test :resource_read do
        metadata do
          id '01'
          name 'Server returns correct Location resource from the Location read interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(
            This test will attempt to Reference to Location can be resolved and read.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Location, [:read])

        location_references = @instance.resource_references.select { |reference| reference.resource_type == 'Location' }
        skip 'No Location references found from the prior searches' if location_references.blank?

        @location_ary = location_references.map do |reference|
          validate_read_reply(
            FHIR::Location.new(id: reference.resource_id),
            FHIR::Location,
            check_for_data_absent_reasons
          )
        end
        @location = @location_ary.first
        @resources_found = @location.present?
      end

      test :validate_resources do
        metadata do
          id '02'
          name 'Location resources returned conform to US Core R4 profiles'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-location'
          description %(

            This test checks if the resources returned from the first search conform to the [US Core Profile](http://hl7.org/fhir/us/core/StructureDefinition/us-core-location).
            This test will check to see if the cardinality and required bindings of elements are respected.
            CodeableConcept element bindings will fail if none of its codings have a code/system that is part of the valueset.
            Quantity, Coding, and code element bindings will fail if its code/system is not found in the valueset.

          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'Location', delayed: true)
        test_resources_against_profile('Location')
        bindings = [
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/location-status',
            path: 'status'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/location-mode',
            path: 'mode'
          },
          {
            type: 'CodeableConcept',
            strength: 'extensible',
            system: 'http://terminology.hl7.org/ValueSet/v3-ServiceDeliveryLocationRoleType',
            path: 'type'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/address-use',
            path: 'address.use'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/address-type',
            path: 'address.type'
          },
          {
            type: 'string',
            strength: 'extensible',
            system: 'http://hl7.org/fhir/us/core/ValueSet/us-core-usps-state',
            path: 'address.state'
          },
          {
            type: 'code',
            strength: 'required',
            system: 'http://hl7.org/fhir/ValueSet/days-of-week',
            path: 'hoursOfOperation.daysOfWeek'
          }
        ]
        invalid_binding_messages = []
        invalid_binding_resources = Set.new
        bindings.select { |binding_def| binding_def[:strength] == 'required' }.each do |binding_def|
          begin
            invalid_bindings = resources_with_invalid_binding(binding_def, @location_ary)
          rescue Inferno::Terminology::UnknownValueSetException => e
            warning do
              assert false, e.message
            end
            invalid_bindings = []
          end
          invalid_bindings.each { |invalid| invalid_binding_resources << "#{invalid[:resource]&.resourceType}/#{invalid[:resource].id}" }
          invalid_binding_messages.concat(invalid_bindings.map { |invalid| invalid_binding_message(invalid, binding_def) })
        end
        assert invalid_binding_messages.blank?, "#{invalid_binding_messages.count} invalid required binding(s) found in #{invalid_binding_resources.count} resources:" \
                                                "#{invalid_binding_messages.join('. ')}"

        bindings.select { |binding_def| binding_def[:strength] == 'extensible' }.each do |binding_def|
          begin
            invalid_bindings = resources_with_invalid_binding(binding_def, @location_ary)
            binding_def_new = binding_def
            # If the valueset binding wasn't valid, check if the codes are in the stated codesystem
            if invalid_bindings.present?
              invalid_bindings = resources_with_invalid_binding(binding_def.except(:system), @location_ary)
              binding_def_new = binding_def.except(:system)
            end
          rescue Inferno::Terminology::UnknownValueSetException, Inferno::Terminology::ValueSet::UnknownCodeSystemException => e
            warning do
              assert false, e.message
            end
            invalid_bindings = []
          end
          invalid_binding_messages.concat(invalid_bindings.map { |invalid| invalid_binding_message(invalid, binding_def_new) })
        end
        warning do
          invalid_binding_messages.each do |error_message|
            assert false, error_message
          end
        end
      end

      test 'All must support elements are provided in the Location resources returned.' do
        metadata do
          id '03'
          link 'http://www.hl7.org/fhir/us/core/general-guidance.html#must-support'
          description %(

            US Core Responders SHALL be capable of populating all data elements as part of the query results as specified by the US Core Server Capability Statement.
            This will look through the Location resources found previously for the following must support elements:

            * status
            * name
            * telecom
            * address
            * address.line
            * address.city
            * address.state
            * address.postalCode
            * managingOrganization
          )
          versions :r4
        end

        skip_if_not_found(resource_type: 'Location', delayed: true)
        must_supports = USCore310LocationSequenceDefinitions::MUST_SUPPORTS

        missing_must_support_elements = must_supports[:elements].reject do |element|
          @location_ary&.any? do |resource|
            value_found = resolve_element_from_path(resource, element[:path]) { |value| element[:fixed_value].blank? || value == element[:fixed_value] }
            value_found.present?
          end
        end
        missing_must_support_elements.map! { |must_support| "#{must_support[:path]}#{': ' + must_support[:fixed_value] if must_support[:fixed_value].present?}" }

        skip_if missing_must_support_elements.present?,
                "Could not find #{missing_must_support_elements.join(', ')} in the #{@location_ary&.length} provided Location resource(s)"
        @instance.save!
      end

      test 'Every reference within Location resources can be read.' do
        metadata do
          id '04'
          link 'http://hl7.org/fhir/references.html'
          description %(

            This test will attempt to read the first 50 reference found in the resources from the first search.
            The test will fail if Inferno fails to read any of those references.

          )
          versions :r4
        end

        skip_if_known_not_supported(:Location, [:search, :read])
        skip_if_not_found(resource_type: 'Location', delayed: true)

        validated_resources = Set.new
        max_resolutions = 50

        @location_ary&.each do |resource|
          validate_reference_resolutions(resource, validated_resources, max_resolutions) if validated_resources.length < max_resolutions
        end
      end
    end
  end
end
