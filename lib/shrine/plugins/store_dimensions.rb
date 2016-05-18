class Shrine
  module Plugins
    # The store_dimensions plugin extracts and stores dimensions of the
    # uploaded image using the [fastimage] gem.
    #
    #     plugin :store_dimensions
    #
    # You can access the dimensions through `#width` and `#height` methods:
    #
    #     uploader = Shrine.new(:store)
    #     uploaded_file = uploader.upload(File.open("image.jpg"))
    #
    #     uploaded_file.width  #=> 300
    #     uploaded_file.height #=> 500
    #
    # The fastimage gem has built-in protection against [image bombs]. However,
    # if for some reason it doesn't suit your needs, you can provide a custom
    # `:analyzer`:
    #
    #     plugin :store_dimensions, analyzer: ->(io, analyzers) do
    #       dimensions = analyzers[:fastimage].call(io)
    #       dimensions || MiniMagick::Image.new(io).dimensions
    #     end
    #
    # [fastimage]: https://github.com/sdsykes/fastimage
    # [image bombs]: https://www.bamsoftware.com/hacks/deflate.html
    module StoreDimensions
      def self.configure(uploader, opts = {})
        uploader.opts[:dimensions_analyzer] = opts.fetch(:analyzer, uploader.opts.fetch(:dimensions_analyzer, :fastimage))
      end

      module InstanceMethods
        # We update the metadata with "width" and "height".
        def extract_metadata(io, context)
          width, height = extract_dimensions(io)

          super.update(
            "width"  => width,
            "height" => height,
          )
        end

        private

        # If the `io` is an uploaded file, copies its dimensions, otherwise
        # calls the predefined or custom analyzer.
        def extract_dimensions(io)
          analyzer = opts[:dimensions_analyzer]
          analyzer = dimensions_analyzers[analyzer] if analyzer.is_a?(Symbol)
          args = [io, dimensions_analyzers].first(analyzer.arity)

          dimensions = analyzer.call(*args)
          io.rewind

          dimensions
        end

        def dimensions_analyzers
          Hash.new { |hash, key| method(:"_extract_dimensions_with_#{key}") }
        end

        def _extract_dimensions_with_fastimage(io)
          require "fastimage"

          dimensions = FastImage.size(io)
          io.rewind

          dimensions
        end
      end

      module FileMethods
        def width
          Integer(metadata["width"]) if metadata["width"]
        end

        def height
          Integer(metadata["height"]) if metadata["height"]
        end
      end
    end

    register_plugin(:store_dimensions, StoreDimensions)
  end
end
