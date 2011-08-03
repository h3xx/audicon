function results=runquery(query)
	delim = ascii(9) // <Tab>
	raw = perl('query.pl', query)

	num_results = size(raw, 1)
	results = []
	for row_num = 1 : num_results
		results = cat(1, results, tokens(raw(row_num), delim)')
	end
endfunction
