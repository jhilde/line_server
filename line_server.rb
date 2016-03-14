require 'sinatra'
require 'thread_safe'

$mutex = Mutex.new

class CacheStrategy
	def initialize(max_cache_size)
	end	

	def [](index)
	end

	def []=(index, value)
	end

	def listing()
	end
end

################################################################################
# class RUCacheStrategy < CacheStrategy
################################################################################
#
# Implements CacheStrategy to create a Most Recently Used (MRU) and 
# Least Recently Used (LRU) cache eviction strategy.
#
###############################################################################

class RUCacheStrategy < CacheStrategy
	@value_list #Array of cached values by index. A nil value indicates the value is NOT cached.
	@cached_list #Array of cached indices ordered by retrieval from the data file
	@max_cache_size #Maximum size (in bytes) of the cached values [exclusive of Array overhead]
	@current_cache_size #Current size (in bytes) of the cached values [exclusive of Array overhead]
	#@mutex #Mutex to lock critical sections (writes to value and cached lists, current_cache_size)
	@most #Boolean true for Most Recently Used strategy, false for Least Recently Used strategy

	################################################################################
	# class RUCacheStrategy < CacheStrategy
	# function initialize
	################################################################################
	#
	# Initializes both value_list and cached_list to be ThreadSafe::Array
	# Sets max_cache_size and most to their inputs
	# Sets current_cache_size to 0
	#
	##############################################################################

	def initialize(max_cache_size, most)
		@value_list = ThreadSafe::Array.new
		@cached_list = ThreadSafe::Array.new
		@max_cache_size = max_cache_size
		@current_cache_size = 0
		#$mutex = Mutex.new
		@most = most
	end

	################################################################################
	# class RUCacheStrategy < CacheStrategy
	# function evict_next
	#      returns evict_value_size #size of value evicted from cache
	################################################################################
	#
	# 1) Removes the head or tail of the cached_list (head for LRU, tail for MRU)
	# 2) Sets the value of the removed item in value_list to nil
	#
	#
	################################################################################

	def evict_next
		if @most
			evict_value_index = @cached_list.pop
		else
			evict_value_index = @cached_list.shift
		end

		if @value_list[evict_value_index] != nil
			evict_value_size = @value_list[evict_value_index].bytesize
		else
			evict_value_size = 0
		end
		
		@value_list[evict_value_index] = nil

		return evict_value_size
	end

	################################################################################
	# class RUCacheStrategy < CacheStrategy
	# function [](index)
	#      returns value #cached value, nil if not in cache
	################################################################################
	#
	# 1) Returns the value associated with index in value_list
	#    [nil indicates not cached]
	#
	################################################################################

	def [](index)
		return @value_list[index]
	end

	################################################################################
	# class RUCacheStrategy < CacheStrategy
	# function []=(index, value)
	################################################################################
	#
	# 1) Returns the value associated with index in value_list
	#    [nil indicates not cached]
	#
	################################################################################
	
	def []=(index,value)
		evicted_size = 0
		$mutex.synchronize {
			if value.bytesize <= @max_cache_size
				if @current_cache_size + value.bytesize > @max_cache_size
					while(evicted_size <= value.bytesize)
						evicted_size = evicted_size + evict_next()
					end
				end
	
				@value_list[index] = value
				@current_cache_size = @current_cache_size + value.bytesize - evicted_size
				@cached_list.push(index)
			end
		}		
	end

	def listing
		return @cached_list.to_s
	end
end	

class RandomCacheStrategy < CacheStrategy
	@value_list
	@cached_list
	@max_cache_size
	@current_cache_size
	@random_number_generator
	#@mutex

	def initialize(max_cache_size)
		@value_list = ThreadSafe::Array.new
		@max_cache_size = max_cache_size
		@current_cache_size = 0
		@random_number_generator = Random.new
		@cached_list = ThreadSafe::Array.new
		#$mutex = Mutex.new
	end

	def evict_next
		if @cached_list.length > 0
		# Need to evict the next cached value
			evict_cached_index = @random_number_generator.rand(@cached_list.length)
			evict_value_index = @cached_list[evict_cached_index]
			
			if(@value_list[evict_value_index])
				evict_value_size = @value_list[evict_value_index].bytesize
			else
				evict_value_size = 0
			end
		
			@cached_list.delete_at(evict_cached_index)
			@value_list[evict_value_index] = nil
			puts "Evicting #{evict_value_index} to save #{evict_value_size}"
			# Let's reset current_cache size in the add @current_cache_size = @current_cache_size - evict_value_size
			return evict_value_size
		else
			return -1
		end
	end

	def [](index)
		return @value_list[index]
	end

	def []=(index,value)
		evicted_size = 0

		$mutex.synchronize {
			#puts @current_cache_size
			#puts @max_cache_size
			if(@current_cache_size + value.bytesize > @max_cache_size && value.bytesize < @max_cache_size)
			#we'll need to do some evicting
			puts "Need to evict current: #{@current_cache_size} space needed: #{value.bytesize}"
			#To make it easier, let's just evict >= bytes as the 
			current_evicted_size = 0

			while(evicted_size <= value.bytesize)
				puts "Already evicted: #{evicted_size}"

				current_evict_size = evict_next
				puts "Now evicted: #{current_evict_size}"

				if current_evict_size > 0
					evicted_size = evicted_size + current_evict_size
					puts "Total evicted: #{evicted_size}"
				else
					puts "Can't cache for some reason"
					exit
					
					return
				end
			end

		end

		
			@value_list[index] = value
			puts "Added line number #{index} to the cache"
			puts "curr size: #{@current_cache_size} new_item_size: #{value.bytesize} evicted: #{evicted_size}"
			@current_cache_size = @current_cache_size + value.bytesize - evicted_size
			puts "new cache size: #{@current_cache_size}"
			@cached_list.push(index)
		}

		#there's room in the cache
		
		puts "Caching: #{index}"
	end

	def listing
		return @cached_list.to_s
	end
end	

class NoCacheStrategy < CacheStrategy

	def initialize()
	end

	def [](index)
		return nil
	end

	def []=(index,value)
	end

	def listing
		return "[]"
	end
end	

class LineFileCache 
  @the_file
  @strategy
  @list_index

  def initialize(filename, strategy)
    @strategy = strategy

    ## index the file
    @list_index = Array.new

    current_pos = 0
    current_index = 0

    IO.foreach(filename) {|x| 
    	#puts "Caching #{current_index}"
		line_length = x.length 
		@list_index[current_index] = current_pos
		current_pos = line_length + current_pos
		current_index = current_index + 1
	}

	fd = IO.sysopen(filename, 'r')
	@the_file = IO.open(fd)
  end

  def [](index)
  	if @strategy[index] != nil
  		#there's a value in the cache
  		return @strategy[index]
  	else
  		#we need to find the value
  		@the_file.seek(@list_index[index], IO::SEEK_SET)

  		if(index < @list_index.length - 1)
  			the_value = @the_file.read(@list_index[index + 1] - @list_index[index] - 2)
  		else
  			the_value = @the_file.read
  		end

  		@strategy[index] = the_value
  	end
  	
  end

  def length
	return @list_index.length
  end

  def cache_listing
  	return @strategy.listing
  end
end

# Initialization

# Grab the filename from the command line arguments
filename = ARGV[0]
cache_strategy_type = ARGV[1]
cache_size = 1000000

if filename == " "
	puts "usage: ruby line_server.rb file [cache_strategy NONE | RR | MRU | LRU] [cache_size]"
	exit
else
	puts "Filename is #{filename}"
end

cache_size = Integer(ARGV[2]) rescue 1000000


case cache_strategy_type
	when "NONE"
  		puts "Using NONE cache strategy"
  		cache_strategy = NoCacheStrategy.new()
  	when "RR"
  		puts "Using RR cache strategy with size #{cache_size}"
  		cache_strategy = RandomCacheStrategy.new(cache_size)
  	when "MRU"
  		puts "Using MRU cache strategy with size #{cache_size}"
  		cache_strategy = RUCacheStrategy.new(cache_size, true)
  	when "LRU"
  		puts "Using LRU cache strategy with size #{cache_size}"
  		cache_strategy = RUCacheStrategy.new(cache_size, false)
	when nil, ""
		puts "Using NONE as default cache strategy"
		cache_strategy = NoCacheStrategy.new()
  	else
  		puts "usage: ruby line_server.rb file [cache_strategy NONE | RR | MRU | LRU] [cache_size]"
  		exit
end


# Create a new LineFileCache instance passing it the filename 
# and an instance of a class that follows the CacheStrategy interface
cache = LineFileCache.new(filename, cache_strategy)

################################################################################
# get for /lines/:line_index
################################################################################
#
# Sinatra get function that handles all /lines/:line_index
# 
# Checks to see if line_index is within the valid line numbers
#    - If it is, defer to the LineFileCache to retrieve the proper value
#      returning it as the body.
#    
#    - If it is NOT, return with a status of 413.
#
###############################################################################

get '/lines/:line_index' do |line_index|
  line_index = line_index.to_i

  if(line_index <= cache.length)
  	body cache[line_index]
  else
  	status 413
  end
end

################################################################################
# get for /cache_listing
################################################################################
#
# Sinatra get function that handles all /cache_listing
# 
# Defers to the LineFileCache to retrieve the currently cached values 
# for debugging.
#
###############################################################################

get '/cache_listing/' do
	body cache.cache_listing
end
  
