require 'epub'
require 'epub/constants'
require 'zipruby'
require 'nokogiri'
require 'tempfile'

module EPUB
  class Parser
    class << self
      # Parse an EPUB file
      #
      # @example
      #   EPUB::Parser.parse('path/to/book.epub') # => EPUB::Book object
      #
      # @example
      #   class MyBook
      #     include EPUB
      #   end
      #   book = MyBook.new
      #   parsed_book = EPUB::Parser.parse('path/to/book.epub', :book => book) # => #<MyBook:0x000000019760e8 @epub_file=..>
      #   parsed_book.equal? book # => true
      #
      # @example
      #   book = EPUB::Parser.parse('path/to/book.epub', :class => MyBook) # => #<MyBook:0x000000019b0568 @epub_file=...>
      #   book.instance_of? MyBook # => true
      #
      # @param [String] filepath
      # @param [Hash] options the type of return is specified by this argument.
      #   If no options, returns {EPUB::Book} object.
      #   For details of options, see below.
      # @option options [EPUB] :book instance of class which includes {EPUB} module
      # @option options [Class] :class class which includes {EPUB} module
      # @return [EPUB] object which is an instance of class including {EPUB} module.
      #   When option :book passed, returns the same object whose attributes about EPUB are set.
      #   When option :class passed, returns the instance of the class.
      #   Otherwise returns {EPUB::Book} object.
      def parse(filepath, options = {})
        new(filepath, options).parse
      end

      def parse_io(io_stream, options = {})
        new(io_stream, options.merge(io: true)).parse_io
      end
    end

    def initialize(datasource, options = {})
      if options[:io]
        raise "IO source not readable" unless datasource.respond_to?(:to_s)

        @io_stream = datasource.force_encoding('UTF-8')
        @book = create_book options
        file = Tempfile.new('epub_string')
        file.write(@io_stream)
        @filepath = file.path
        @book.epub_file = @filepath
      else
        raise "File #{datasource} not readable" unless File.readable_real? datasource

        @filepath = File.realpath datasource
        @book = create_book options
        @book.epub_file = @filepath
      end
    end

    def parse
      Zip::Archive.open @filepath do |zip|
        @book.ocf = OCF.parse(zip)
        @book.package = Publication.parse(zip, @book.ocf.container.rootfile.full_path.to_s)
      end

      @book
    end

    def parse_io # unnecessary, but desirable maybe?
      Zip::Archive.open_buffer @io_stream do |zip|
        @book.ocf = OCF.parse(zip)
        @book.package = Publication.parse(zip, @book.ocf.container.rootfile.full_path.to_s)
      end

      @book
    end

    private

    def create_book(params)
      case
      when params[:book]
        params[:book]
      when params[:class]
        params[:class].new
      else
        require 'epub/book'
        Book.new
      end
    end
  end
end

require 'epub/parser/version'
require 'epub/parser/utils'
require 'epub/parser/ocf'
require 'epub/parser/publication'
require 'epub/parser/content_document'
