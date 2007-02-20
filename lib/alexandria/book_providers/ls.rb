# Copyright (C) 2004 Laurent Sansonetti
#
# Alexandria is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# Alexandria is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with Alexandria; see the file COPYING.  If not,
# write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA 02111-1307, USA.

# Adapted code from 'bn.rb' (I hope that it works!)

require 'net/http'
require 'cgi'

module Alexandria
class BookProviders
    class SicilianoProvider < GenericProvider
    
        BASE_URI = "http://www.siciliano.com.br"
        def initialize
            super("LS", "Livraria Siliciano (Brasil)")
            # no preferences for the moment
        end
        
        def search(criterion, type)
            criterion = criterion.convert("iso-8859-1", "utf-8")
            req = BASE_URI + "/livro.asp?tipo=10&pesquisa=" 
            req += case type
                when SEARCH_BY_ISBN
                    "5&id="

               # when SEARCH_BY_TITLE
               #     "1&id="
               #
               # when SEARCH_BY_AUTHORS
               #     "3&id="
               #
                else
                    raise InvalidSearchTypeError

            end

            criterion = Library.canonicalise_isbn(criterion) if type == SEARCH_BY_ISBN
            req += CGI.escape(criterion)
            p req if $DEBUG
            data = transport.get(URI.parse(req))

            if type == SEARCH_BY_ISBN
                book = to_book(data, req)            
            #else
            #    begin
            #        results = [] 
            #        each_book_page(data) do |page, title|
            #            results << to_book(transport.get(URI.parse(BASE_URI + page)))
            #        end
            #        return results 
            #    rescue
            #        raise NoResultsError
            #    end
            end
            book
        end

        def url(book)
	    "http://www.siciliano.com.br/livro.asp?tipo=10&pesquisa=5&id=" +  Library.canonicalise_isbn(book.isbn)
        end

        #######
        private
        #######
   
        def to_book(data, req)
            data = data.convert("UTF-8", "iso-8859-1")
            raise "No Title" unless md = /'><strong>([^<]+)<\/strong><\/a><br\/>/.match(data)
            title = md[1].strip
            authors = []
            raise "No Author" unless md =/<strong class="azulescuro">(.*)<\/strong><br\/><br\/>/.match(data)
            md[1].strip.split(', ').each { |a| authors << CGI.unescape(a.strip) }
            raise "No ISBN from Image" unless md = /<img src="capas\/([^<]+)p\.jpg" alt=""\/>/.match(data)
            isbn = md[1].strip
            if md = /<br\/>Editora: ([^<]+)<br>/.match(data)
                publisher = md[1].strip
            else
                publisher = nil
            end
            edition = nil
            publish_year = nil
            medium_cover = BASE_URI+'/capas/'+ isbn + '.jpg'
            #raise "No Big Image" unless medium_cover = transport.get(URI.parse(BASE_URI+'/capas/'+ isbn + '.jpg'))
            #raise "No Big Image" unless md = /<img src="capas\/(.+\/(\d+)p\.gif)" alt=""\/>/.match(data)
            #medium_cover = md[1]
            #small_cover = md[1]
            return [ Book.new(title, authors, isbn, publisher, publish_year, edition), 
                     medium_cover ]
        end
    
        # def each_book_page(data)
        #     raise if data.scan(/<A href="(\/booksearch\/isbnInquiry.asp\?userid=[\w\d]+&isbn=[^"]+)">([^<]+)<\/A>/) { |a| yield a }.empty?
        # end
    end
end
end
