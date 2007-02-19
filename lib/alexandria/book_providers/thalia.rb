# Copyright (C) 2005-2006 Rene Samselnig
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

# http://de.wikipedia.org/wiki/Thalia_%28Buchhandel%29
# Thalia.de bought the Austrian book trade chain Amadeus

require 'net/http'
require 'cgi'

module Alexandria
class BookProviders
    class ThaliaProvider < GenericProvider
    
        BASE_URI = "http://www.thalia.de/"
        def initialize
            super("Thalia", "Thalia (Germany)")
            # no preferences for the moment
        end
        
        def search(criterion, type)
            req = BASE_URI + "shop/bde_bu_hg_startseite/schnellsuche/buch/?"
            #if type == SEARCH_BY_ISBN
            #    req += ""
            #else
            #    req += "act=suchen&"
            #end
            req += case type
                when SEARCH_BY_ISBN
                    "fqbi="

                when SEARCH_BY_TITLE
                    "fqbt="

                when SEARCH_BY_AUTHORS
                    "fqba="

                when SEARCH_BY_KEYWORD
                    "fqbs="

                else
                    raise InvalidSearchTypeError

            end
            req += CGI.escape(criterion)
            data = transport.get(URI.parse(req))
            if type == SEARCH_BY_ISBN
                to_book(data) #rescue raise NoResultsError
            else
                begin
                    results = [] 
                    each_book_page(data) do |page, title|
                        results << to_book(transport.get(URI.parse(BASE_URI + page)))
                    end
                    return results 
                rescue
                    raise NoResultsError
                end
            end
        end

        def url(book)
            return nil unless book.isbn
            BASE_URI + "shop/bde_bu_hg_startseite/schnellsuche/buch/?fqbi=" + book.isbn
        end

        #######
        private
        #######
    
        def to_book(data)
						puts data if $DEBUG
						data = data.convert("UTF-8", "iso-8859-1")
						product = {}
						# title
            raise "No Title" unless md = /<span id="_artikel_titel">(.+)<\/span><span class="foobar">/.match(data)
            product["title"] = md[1].strip.unpack("C*").pack("U*")
						# authors
						product["authors"] = []
						data.scan(/\?fqba=([^"]+)" title="Mehr von..."><u>([^<]+)<\/u>/) do |md|
                next unless CGI.unescape(md[0]) == md[1]
                product["authors"] << md[1].unpack("C*").pack("U*")
            end
            #raise if product["authors"].empty?
						# isbn
            raise "No isbn" unless md = /<strong>ISBN-10:<\/strong>(.+)<\/li>/.match(data)
            product["isbn"] = md[1].strip.gsub(/-/, "")
						# edition
            md = /<strong>Einband:<\/strong> ([^,]<)/.match(data)
            product["edition"] = md[1].strip.unpack("C*").pack("U*") if md != nil
						# publisher
            md = /<strong>Erschienen +bei:<\/strong> ([^<]+)/.match(data)
            product["publisher"] = md[1].strip.unpack("C*").pack("U*").split(/ /).each { |e| e.capitalize! }.join(" ") if md != nil
						# cover
            raise "No cover image" unless md = /<img id="_artikel_mediumthumbnail" src="([^"]+)/.match(data)
            product["cover"] = md[1] if md != nil
            book = Book.new(product["title"],
						                product["authors"],
									  				product["isbn"],
														product["publisher"],
                                                         nil, # TODO - furnish publish year
														product["edition"])
						return [ book, product["cover"] ]
        end

				def each_book_page(data)
				    raise if data.scan(/<a href="#{BASE_URI}(shop\/bde_bu_hg_startseite\/artikeldetails\/[^\.]+\.html)\;jsessionid=[^"]+" title="Details zu diesem Produkt sehen..."><img class="left" width="40" height="60" src="[^"]+" alt="([^"]+)" border="0">/) { |a| yield a }.empty?
				end
    end
end
end