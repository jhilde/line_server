require 'net/http'

#http = Net::HTTP.new('localhost', 4567)
#http.get('/lines/500')



def hit_website
	random_number_generator = Random.new

	

	timings = Array.new
	
	100000.times {
		http = Net::HTTP.new('localhost', 4567)
		index = 0
		while index == 0 || index > 1000
			index = rand(1000)
		end
		start = Time.now
		response = http.get('/lines/' + index.to_s)
		#puts response.body
		stop = Time.now
		timings << stop - start
		#sleep rand(10)
	}

	total = 0.0
	timings.each { |timing| 
		total = total + timing
	}

	average = total / timings.length * 1000

	puts "Average: #{average}"
	
end

threads = []
5.times {
	threads << Thread.new { hit_website }
}

threads.each { |thr| thr.join }
