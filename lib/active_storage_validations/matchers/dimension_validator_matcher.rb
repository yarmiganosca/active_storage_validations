# frozen_string_literal: true

require_relative 'concerns/active_storageable.rb'
require_relative 'concerns/contextable.rb'
require_relative 'concerns/messageable.rb'
require_relative 'concerns/validatable.rb'

module ActiveStorageValidations
  module Matchers
    def validate_dimensions_of(name)
      DimensionValidatorMatcher.new(name)
    end

    class DimensionValidatorMatcher
      include ActiveStorageable
      include Contextable
      include Messageable
      include Validatable

      def initialize(attribute_name)
        @attribute_name = attribute_name
        @width_min = @width_max = @height_min = @height_max = nil
      end

      def description
        "validate image dimensions of #{@attribute_name}"
      end

      def width_min(width)
        @width_min = width
        self
      end

      def width_max(width)
        @width_max = width
        self
      end

      def width(width)
        @width_min = @width_max = width
        self
      end

      def height_min(height)
        @height_min = height
        self
      end

      def height_max(height)
        @height_max = height
        self
      end

      def width_between(range)
        @width_min, @width_max = range.first, range.last
        self
      end

      def height_between(range)
        @height_min, @height_max = range.first, range.last
        self
      end

      def height(height)
        @height_min = @height_max = height
        self
      end

      def matches?(subject)
        @subject = subject.is_a?(Class) ? subject.new : subject

        is_a_valid_active_storage_attribute? &&
          is_context_valid? &&
          width_not_smaller_than_min? &&
          width_larger_than_min? &&
          width_smaller_than_max? &&
          width_not_larger_than_max? &&
          width_equals? &&
          height_not_smaller_than_min? &&
          height_larger_than_min? &&
          height_smaller_than_max? &&
          height_not_larger_than_max? &&
          height_equals? &&
          is_custom_message_valid?
      end

      def failure_message
        <<~MESSAGE
          is expected to validate dimensions of #{@attribute_name}
            width between #{@width_min} and #{@width_max}
            height between #{@height_min} and #{@height_max}
        MESSAGE
      end

      protected

      def valid_width
        ((@width_min || 0) + (@width_max || 2000)) / 2
      end

      def valid_height
        ((@height_min || 0) + (@height_max || 2000)) / 2
      end

      def width_not_smaller_than_min?
        @width_min.nil? || !passes_validation_with_dimensions(@width_min - 1, valid_height, 'width')
      end

      def width_larger_than_min?
        @width_min.nil? || @width_min == @width_max || passes_validation_with_dimensions(@width_min + 1, valid_height, 'width')
      end

      def width_smaller_than_max?
        @width_max.nil? || @width_min == @width_max || passes_validation_with_dimensions(@width_max - 1, valid_height, 'width')
      end

      def width_not_larger_than_max?
        @width_max.nil? || !passes_validation_with_dimensions(@width_max + 1, valid_height, 'width')
      end

      def width_equals?
        @width_min.nil? || @width_min != @width_max || passes_validation_with_dimensions(@width_min, valid_height, 'width')
      end

      def height_not_smaller_than_min?
        @height_min.nil? || !passes_validation_with_dimensions(valid_width, @height_min - 1, 'height')
      end

      def height_larger_than_min?
        @height_min.nil? || @height_min == @height_max || passes_validation_with_dimensions(valid_width, @height_min + 1, 'height')
      end

      def height_smaller_than_max?
        @height_max.nil? || @height_min == @height_max || passes_validation_with_dimensions(valid_width, @height_max - 1, 'height')
      end

      def height_not_larger_than_max?
        @height_max.nil? || !passes_validation_with_dimensions(valid_width, @height_max + 1, 'height')
      end

      def height_equals?
        @height_min.nil? || @height_min != @height_max || passes_validation_with_dimensions(valid_width, @height_min, 'height')
      end

      def passes_validation_with_dimensions(width, height, check)
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

      def mock_dimensions_for(attachment, width, height)
        Matchers.mock_metadata(attachment, width, height) do
          yield
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
    end
  end
end
