# Copyright (C) 2005-2006 Mathieu Leduc-Hamel
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

require 'net/http'
require 'cgi'

module Alexandria
  class BookProviders
    class RENAUDProvider < GenericProvider
      include GetText
      GetText.bindtextdomain(Alexandria::TEXTDOMAIN, nil, nil, "UTF-8")
      BASE_URI = "http://www.renaud-bray.com/"
      ACCENTUATED_CHARS = "áàâäçéèêëíìîïóòôöúùûü"

      def initialize
        super("RENAUD", "Renaud-Bray")
      end

      def search(criterion, type)
        req = BASE_URI + "francais/menu/gabarit.asp?Rubrique=&Recherche=&Entete=Livre&Page=Recherche_section_wsc.asp&OnlyAvailable=false&Tri="
        req += case type
               when SEARCH_BY_ISBN
                 "ISBN"
               when SEARCH_BY_TITLE
                 "Titre"
               when SEARCH_BY_AUTHORS
                 "Auteur"
               when SEARCH_BY_KEYWORD
                 ""
               else
                 raise InvalidSearchTypeError
               end
        req += "&Phrase="
        req += CGI.escape(criterion)
        data = transport.get(URI.parse(req))
        begin
          if type == SEARCH_BY_ISBN
            return to_books(data).pop()
          else
            results = []
            to_books(data).each{|book| 
              results << book 
            }
            while /Suivant/.match(data)
              md = /Enteterouge\">([\d]*)<\/b>/.match(data)
              num = md[1].to_i+1
              data = transport.get(URI.parse(req+"&PageActuelle="+num.to_s))
              to_books(data).each{|book| 
                results << book 
              }
            end
            return results
          end
        rescue
          raise NoResultsError
        end
      end

      def url(book)
        "http://www.renaud-bray.com/francais/menu/gabarit.asp?Rubrique=&Recherche=&Entete=Livre&Page=Recherche_section_wsc.asp&OnlyAvailable=false&Tri=ISBN&Phrase=" + book.isbn
      end

      #######
      private
      #######
      
      def to_books(data)
        # Make it sure that we are in utf-8
        data = data.convert("UTF-8", "iso-8859-1")
        titles = []
        data.scan(/"LireHyperlien" href.*><b>([-,'&;\w\s#{ACCENTUATED_CHARS}]*)<\/b><\/a><br>/).each{|md|
          titles << md[0].strip
        }
        raise if titles.empty?
        authors = []
        data.scan(/Nom_Auteur.*><i>([,'.&;\w\s#{ACCENTUATED_CHARS}]*)<\/i>/).each{|md|
          authors2 = []
          for author in md[0].split('  ')
            authors2 << author.strip
          end
          authors << authors2
        }
        raise if authors.empty?
        isbns = []
        data.scan(/ISBN :([\dX]*)/).each{|md|
          isbns << md[0].strip
        }
        raise if isbns.empty?
        editions = []
        data.scan(/Date : <br>(\d{4,}-\d{2,}-\d{2,})/).each{|md|
          editions << md[0].strip
        }
        raise if editions.empty?
        publishers = []
        data.scan(/diteur : ([,'.&;\w\s#{ACCENTUATED_CHARS}]*)<\/span><br>/).each{|md|
          publishers << md[0].strip
        }
        raise if publishers.empty?
        book_covers = []
        data.scan(/(\/ImagesEditeurs\/[\d]*\/([\dX]*-f.(jpg|gif))|\/francais\/suggestion\/images\/livre\/livre.gif)/).each{|md|
          book_covers << BASE_URI + md[0].strip
        }
        raise if book_covers.empty?
        
        books = []
        titles.each_with_index{|title, i|
          books << [Book.new(title, authors[i], isbns[i], publishers[i], editions[i]), 
            book_covers[i]]
        }
        raise if books.empty?

        return books
      end

    end
  end
end