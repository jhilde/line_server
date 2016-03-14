file_val = IO.sysopen("/Volumes/Lexar/HugeFile.txt", 'w+')
fd = IO.open(file_val)

for i in 1..1000000000
   fd.write("Line #{i} because this is the best way to do this by generating a very long line!\n")
end


fd.close
