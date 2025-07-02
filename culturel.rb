require 'mechanize'
require 'csv'
require 'json'

# Initialize a new Mechanize agent
agent = Mechanize.new

# Get the list file name from command-line args or default to 'list.txt'
list_file = ARGV[0] || 'list.txt'
part_number = ARGV[1] || '0'

# Read URLs from the list file
urls = File.readlines(list_file).map(&:strip)

# Array to hold the scraped data
books = []

# Iterate through each URL
urls.each do |url|
  begin
    loop do
      # Fetch the page
      page = agent.get(url)

      # Debug: Print page title
      puts "Page Title: #{page.title}"

      # Extract genre from URL
      genre = url.gsub("https://www.culturel.tn/livre/", "").gsub(".html", "")

      # Find book containers
      book_containers = page.search('.infoallprod')
      puts "Number of book containers found: #{book_containers.size}"

      book_containers.each do |container|
        begin
          book_link = container.at('h3 a')['href']
          title = container.at('h3 a')&.text&.strip || "N/A"

          author = container.at('.nameauteur a')&.text&.strip
          author = author.nil? || author.empty? ? 'N/A' : author

          publisher = container.at('.nameauteur a:nth-of-type(2)')&.text&.strip || "N/A"
          publisher = publisher.nil? || publisher.empty? ? 'N/A' : publisher

          isbn = container.at('.isbn')&.text&.strip&.gsub('ISBN : ', '')
          isbn = isbn.nil? || isbn.empty? ? 'N/A' : isbn

          price = container.at('.nv-prix')&.text&.strip || "N/A"

          # Navigate to book detail page
          book_page = agent.click(container.at('h3 a'))

          publication_date = book_page.search('.informations-container .information:nth-of-type(2)')&.text&.strip
          year = (publication_date && publication_date.length >= 4) ? publication_date[0..3] : 'N/A'

          summary = container.at('.short_description')&.text&.strip || "N/A"
          summary = summary.nil? || summary.empty? ? 'N/A' : summary

          image_link = book_page.at('img#image')['src'] if book_page.at('img#image')

          book_data = {
            title: title,
            author: author,
            publisher: publisher,
            isbn: isbn,
            price: price,
            summary: summary,
            link: book_link,
            year: year,
            genre: genre,
            image_link: image_link,
            pageurl: url
          }

          # Print book info
          puts "Title: #{book_data[:title]}"
          puts "Author: #{book_data[:author]}"
          puts "Publisher: #{book_data[:publisher]}"
          puts "ISBN: #{book_data[:isbn]}"
          puts "Price: #{book_data[:price]}"
          puts "Summary: #{book_data[:summary]}"
          puts "Link: #{book_data[:link]}"
          puts "Year: #{book_data[:year]}"
          puts "Genre: #{book_data[:genre]}"
          puts "Image Link: #{book_data[:image_link]}"
          puts "URL: #{book_data[:pageurl]}"
          puts "-----------------------------"

          # Add to books array
          books << book_data

          # Append to CSV
          CSV.open("books.csv", "ab") do |csv|
            csv << [
              book_data[:title], book_data[:author], book_data[:publisher], book_data[:isbn],
              book_data[:price], book_data[:summary], book_data[:link], book_data[:year],
              book_data[:genre], book_data[:image_link]
            ]
          end
        rescue => e
          puts "Error processing book: #{e.message}"
          puts "Container HTML: #{container.to_html}"
        end
      end

      # Save progress after processing this page
      File.open("books.json", "w") do |f|
        f.write(JSON.pretty_generate(books))
      end

      # Check for next page link
      next_page = page.at('a.next')
      break unless next_page

      url = next_page['href']
    end
  rescue => e
    puts "Error processing URL #{url}: #{e.message}"
  end
end

# Write final results at end
File.write("books_part_#{part_number}.json", JSON.pretty_generate(books))
File.write("books.json", JSON.pretty_generate(books))

puts "Scraping completed. Data exported to books.csv and books_part_#{part_number}.json."
