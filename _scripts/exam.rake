require 'erb'
require 'yaml'

task :exam do
	Dir.foreach("_exams") do |yer|
		if (yer == 'progdil-2011.yml')
			puts yer

	yukle = YAML::load_file("_exams/" + yer)
	baslik = yukle["title"]
	sorular = yukle["q"]
	alt = yukle["footer"]
	
	i = 0
	icerik = []

	for j  in sorular 


		icerik[i]=File.read("_includes/q/"+j)
	i = i + 1	
        end
	oku = File.read("_templates/exam.md.erb")
	file = File.open("odev.md","w")
	son = ERB.new(oku)
	file.write(son.result(binding))
	file.close

	sh "markdown2pdf odev.md "	
	sh "rm odev.md"	
end
end
end
task:default => :exam
