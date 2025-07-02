require 'mechanize'
require 'csv'
require 'json'

# Initialize a new Mechanize agent
agent = Mechanize.new




# Get the list file name from command-line args or default to 'list.txt'
list_file = ARGV[0] || 'list.txt'

# Read URLs from the list file
#urls = File.readlines(list_file).map(&:strip)
# Read URLs from urls.txt
urls = File.readlines('list').map(&:strip)

# Array to hold the scraped data
books = []

# Load existing data from JSON if available
if File.exist?("books.json")
  books = JSON.parse(File.read("books.json"), symbolize_names: true)
end

# Load completed URLs if available
completed_urls = if File.exist?("completed_urls.txt")
                   File.readlines("completed_urls.txt").map(&:strip)
                 else
                   []
                 end

# Filter URLs to process only uncompleted ones
urls_to_process = urls - completed_urls

# Load existing CSV data if available
saved_books = {}
if File.exist?("books.csv")
  CSV.foreach("books.csv", headers: true) do |row|
    saved_books["#{row['Title']}-#{row['Author']}"] = true
  end
end

# Iterate through each URL
urls_to_process.each do |url|
#page_number = 1
  begin
    loop do
      # Fetch the page
      page = agent.get(url)

      # Debugging: Print the page title to confirm we fetched the correct page
      puts "Page Title: #{page.title}"

      # Extract genre from the URL
      genre = url.gsub("https://www.culturel.tn/livre/", "").gsub(".html", "")

      # Find all book containers on the page
      book_containers = page.search('.infoallprod')

      # Debugging: Print the number of book containers found
      puts "Number of book containers found: #{book_containers.size}"

      # Iterate through each book container
      book_containers.each do |container|
        begin
          # Extract the book link
          book_link = container.at('h3 a')['href']
          title = container.at('h3 a')&.text&.strip || "N/A"

         author = container.at('.nameauteur a')&.text&.strip

    # Replace missing author with 'N/A'
    author = author.nil? || author.empty? ? 'N/A' : author


          # Check if the book is already saved
          next if saved_books["#{title}-#{author}"]

          # Extract publisher (the second <a> tag in the .nameauteur div)
          publisher = container.at('.nameauteur a:nth-of-type(2)')&.text&.strip || "N/A"
publisher = publisher.nil? || publisher.empty? ? 'N/A' : publisher
          # Extract ISBN
         
isbn = container.at('.isbn')&.text&.strip&.gsub('ISBN : ', '')

# Replace missing ISBN with 'N/A'
isbn = isbn.empty? ? 'N/A' : isbn


          # Extract price
          price = container.at('.nv-prix')&.text&.strip || "N/A"

          # Click the book link to navigate to the book's detail page
          book_page = agent.click(container.at('h3 a'))

          # Extract the publication year from the new structure
         publication_date = book_page.search('.informations-container .information:nth-of-type(2)')&.text&.strip

# Extract the year if publication_date is present
year = if publication_date && publication_date.length >= 4
          publication_date[0..3]
        else
          'N/A'
        end


          # Extract summary
          summary = container.at('.short_description')&.text&.strip || "N/A"
summary = summary.nil? || summary.empty? ? 'N/A' : summary

          # Extract image link
          image_link = book_page.at('img#image')['src'] if book_page.at('img#image') 

          # Store the scraped data in a hash
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

          # Print the scraped data sequentially
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
          puts "pageurl: #{book_data[:pageurl]}"  
          puts "-----------------------------"

          # Add the book data to the array
          books << book_data

          # Append the new book data to the CSV file
          CSV.open("books.csv", "ab") do |csv|
            csv << [book_data[:title], book_data[:author], book_data[:publisher], book_data[:isbn], book_data[:price],
                    book_data[:summary], book_data[:link], book_data[:year], book_data[:genre], book_data[:image_link]]
          end

          # Mark the book as saved
          saved_books["#{title}-#{author}"] = true
        rescue => e
          puts "Error processing book: #{e.message}"
          puts "Container HTML: #{container.to_html}" # Print the HTML of the container for debugging
        end
      end

      # Save the current state to JSON after processing each page
      File.open("books.json", "w") do |f|
        f.write(JSON.pretty_generate(books))
      end
File.write("books_part_#{part_number}.json", JSON.pretty_generate(books))

      # Check for the "Next" button and update the URL if it exists
      next_page = page.at('a.next')
      break unless next_page # Exit the loop if there is no next page
# Increment page number BEFORE changing the URL
page_number += 1
 next_page = page.at('a.next')
    break unless next_page

    # Update URL and increment page number
    url = next_page['href']
    #page_number += 1
  end

  # Mark original URL (not next_page!) as completed
  File.open("completed_urls.txt", "a") { |f| f.puts urls_to_process.find { |u| url.include?(u) } }

rescue => e
  puts "Error processing URL: #{e.message}"
end

end
# Print completion message
puts "Scraping completed. Data exported to books.csv and books.json."
