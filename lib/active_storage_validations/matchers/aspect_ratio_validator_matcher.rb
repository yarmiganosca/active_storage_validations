# frozen_string_literal: true

require_relative 'concerns/active_storageable.rb'
require_relative 'concerns/contextable.rb'
require_relative 'concerns/messageable.rb'
require_relative 'concerns/validatable.rb'

module ActiveStorageValidations
  module Matchers
    def validate_aspect_ratio_of(name, expected_aspect_ratio)
      AspectRatioValidatorMatcher.new(name, expected_aspect_ratio)
    end

    class AspectRatioValidatorMatcher
      include ActiveStorageable
      include Contextable
      include Messageable
      include Validatable

      def initialize(attribute_name)
        @attribute_name = attribute_name
        @allowed_aspect_ratios = @rejected_aspect_ratios = []
      end

      def description
        "validate the aspect ratios allowed on attachment #{@attribute_name}."
      end

      def allowing(*aspect_ratios)
        @allowed_aspect_ratios = aspect_ratios.flatten
        self
      end

      def rejecting(*aspect_ratios)
        @rejected_aspect_ratios = aspect_ratios.flatten
        self
      end

      def matches?(subject)
        @subject = subject.is_a?(Class) ? subject.new : subject

        is_a_valid_active_storage_attribute? &&
          is_context_valid? &&
          all_allowed_aspect_ratios_allowed? &&
          all_rejected_aspect_ratios_rejected? &&
          is_custom_message_valid?
      end

      def failure_message
        "is expected to validate aspect ratio of #{@attribute_name}"
      end

      protected

      def all_allowed_aspect_ratios_allowed?
        @allowed_aspect_ratios_not_allowed ||= @allowed_aspect_ratios.reject { |aspect_ratio| aspect_ratio_allowed?(aspect_ratio) }
        @allowed_aspect_ratios_not_allowed.empty?
      end

      def all_rejected_aspect_ratios_rejected?
        @rejected_aspect_ratios_not_rejected ||= @rejected_aspect_ratios.select { |aspect_ratio| aspect_ratio_allowed?(aspect_ratio) }
        @rejected_aspect_ratios_not_rejected.empty?
      end

      def aspect_ratio_allowed?(aspect_ratio)
        width, height = valid_width_and_height_for(aspect_ratio)

        mock_dimensions_for(attach_file, width, height) do
          validate
          is_valid?
        end
      end

      def is_custom_message_valid?
        return true unless @custom_message

        mock_dimensions_for(attach_file, -1, -1) do
          validate
          has_an_error_message_which_is_custom_message?
        end
      end

      def attach_file
        @subject.public_send(@attribute_name).attach(dummy_file)
        @subject.public_send(@attribute_name)
      end

      def dummy_file
        {
          io: Tempfile.new('Hello world!'),
          filename: 'test.png',
          content_type: 'image/png'
        }
      end

      def mock_dimensions_for(attachment, width, height)
        Matchers.mock_metadata(attachment, width, height) do
          yield
        end
      end

      def valid_width_and_height_for(aspect_ratio)
        case aspect_ratio
        when :square then [100, 100]
        when :portrait then [100, 200]
        when :landscape then [200, 100]
        when validator_class::ASPECT_RATIO_REGEX
          aspect_ratio =~ validator_class::ASPECT_RATIO_REGEX
          x = Regexp.last_match(1).to_i
          y = Regexp.last_match(2).to_i

          [100 * x, 100 * y]
        else
          [-1, -1]
        end
      end
    end
  end
end
