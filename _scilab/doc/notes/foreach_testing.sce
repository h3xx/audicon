fcns = []; for i = [ 'clip' 'tex' ]; for p = [ 'prev' 'curr' 'next' ]; fcns = [ fcns sprintf('size(%s_%s, ''c'')', p, i) ]; end; end
