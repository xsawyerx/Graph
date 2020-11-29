package Graph::AdjacencyMap::Heavy;

# THIS IS INTERNAL IMPLEMENTATION ONLY, NOT TO BE USED DIRECTLY.
# THE INTERFACE IS HARD TO USE AND GOING TO STAY THAT WAY AND
# ALMOST GUARANTEED TO CHANGE OR GO AWAY IN FUTURE RELEASES.

use strict;
use warnings;

# $SIG{__DIE__ } = \&Graph::__carp_confess;
# $SIG{__WARN__} = \&Graph::__carp_confess;

use Graph::AdjacencyMap qw(:flags :fields);
use base 'Graph::AdjacencyMap';

require overload; # for de-overloading

sub stringify {
    my $m = shift;
    my @rows;
    my $a = $m->[ _a ];
    my $s = $m->[ _s ];
    if ($a == 2) {
	my (%p, %s);
	for my $t ($m->paths) {
	    my ($u, $v) = @$t;
	    $p{$u} = $s{$v} = 1;
	}
	my @s = sort keys %s;
	@rows = [ 'to:', @s ];
	for my $u (sort keys %p) {
	    my @r = $u;
	    for my $v (@s) {
		if (!$m->__has_path($u, $v)) {
		    push @r, '';
		    next;
		}
		my $v = $s->{$u}{$v};
		push @r, $m->_dumper(ref $v ? $v->[-1] : defined $v ? 1 : '');
	    }
	    push @rows, \@r;
	}
    } elsif ($a == 1) {
        my $s = $m->[ _s ];
	my $d;
	push @rows, map [ $_, ref($d=$s->{$_}) ? $m->_dumper($d->[-1]) : $d ],
	    sort map @$_, $m->paths;
    }
    $m->SUPER::stringify . join '',
        map "$_\n",
        map join(' ', map sprintf('%4s', $_), @$_),
        @rows;
}

sub __set_path {
    my $m = shift;
    my $f = $m->[ _f ];
    my $id = pop if $f & _MULTI;
    Graph::__carp_confess(sprintf "Graph::AdjacencyMap::Heavy: arguments %d expected %d",
	scalar @_, $m->[ _a ]) if @_ != $m->[ _a ] && !($f & _HYPER);
    my $p;
    $p = ($f & _HYPER) ?
	(( $m->[ _s ] ||= [ ] )->[ @_ ] ||= { }) :
	(  $m->[ _s ]                   ||= { });
    my @p = $p;
    my @k;
    @_ = sort @_ if $f & _UNORD;
    while (@_) {
	my $k = shift;
	my $q = ref $k && ($f & _REF) && overload::Method($k, '""') ? overload::StrVal($k) : $k;
	if (@_) {
	    $p = $p->{ $q } ||= {};
	    return unless $p;
	    push @p, $p;
	}
	push @k, $q;
    }
    return (\@p, \@k);
}

sub __set_path_node {
    my ($m, $p, $l) = splice @_, 0, 3;
    my $f = $m->[ _f ] ;
    my $id = pop if ($f & _MULTI);
    unless (exists $p->[-1]->{ $l }) {
	my $i = $m->_new_node( \$p->[-1]->{ $l }, $id );
	$m->[ _i ]->{ defined $i ? $i : "" } = [ @_ ];
        return defined $id ? ($id eq _GEN_ID ? $$id : $id) : $i;
    } else {
	return $m->_inc_node( \$p->[-1]->{ $l }, $id );
    }
}

sub set_path {
    my $m = shift;
    my $f = $m->[ _f ];
    return if @_ == 0 && !($f & _HYPER);
    if (@_ > 1 && ($f & _UNORDUNIQ)) {
	if (($f & _UNORDUNIQ) == _UNORD && @_ == 2) { @_ = sort @_ }
        else { $m->__arg(\@_) }
    }
    my ($p, $k) = $m->__set_path( @_ );
    return unless defined $p && defined $k;
    my $l = defined $k->[-1] ? $k->[-1] : "";
    return $m->__set_path_node( $p, $l, @_ );
}

sub __has_path {
    my $m = shift;
    my $f = $m->[ _f ];
    Graph::__carp_confess(sprintf "Graph::AdjacencyMap::Heavy: arguments %d expected %d",
	scalar @_, $m->[ _a ]) if @_ != $m->[ _a ] && !($f & _HYPER);
    if (@_ > 1 && ($f & _UNORDUNIQ)) {
	if (($f & _UNORDUNIQ) == _UNORD && @_ > 1) { @_ = sort @_ }
        else { $m->__arg(\@_) }
    }
    my $p = $m->[ _s ];
    return unless defined $p;
    $p = $p->[ @_ ] if ($f & _HYPER);
    return unless defined $p;
    my @p = $p;
    my @k;
    while (@_) {
	my $k = shift;
	my $q = ref $k && ($f & _REF) && overload::Method($k, '""') ? overload::StrVal($k) : $k;
	if (@_) {
	    $p = $p->{ $q };
	    return unless defined $p;
	    push @p, $p;
	}
	push @k, $q;
    }
    return (\@p, \@k);
}

sub has_path {
    my $m = shift;
    my $f = $m->[ _f ];
    my ($p, $k) = $m->__has_path( @_ );
    return unless defined $p && defined $k;
    return exists $p->[-1]->{ defined $k->[-1] ? $k->[-1] : "" };
}

sub has_path_by_multi_id {
    my $m = shift;
    my $f = $m->[ _f ];
    my $id = pop;
    my ($e, $n) = $m->__get_path_node( @_ );
    return undef unless $e;
    return exists $n->[ _nm ]->{ $id };
}

sub _get_path_node {
    my $m = shift;
    my $f = $m->[ _f ];
    if ($m->[ _a ] == 2 && @_ == 2 && !($f & (_HYPER|_REF|_UNIQ))) { # Fast path.
	@_ = sort @_ if $f & _UNORD;
	return unless exists $m->[ _s ]->{ $_[0] };
	my $p = [ $m->[ _s ], $m->[ _s ]->{ $_[0] } ];
	my $k = [ $_[0], $_[1] ];
	my $l = $_[1];
	return ( exists $p->[-1]->{ $l }, $p->[-1]->{ $l }, $p, $k, $l );
    }
    $m->__get_path_node( @_ );
}

sub _get_path_id {
    my $m = shift;
    my $f = $m->[ _f ];
    my ($e, $n);
    if ($m->[ _a ] == 2 && @_ == 2 && !($f & (_HYPER|_REF|_UNIQ))) { # Fast path.
	@_ = sort @_ if $f & _UNORD;
	return unless exists $m->[ _s ]->{ $_[0] };
	my $p = $m->[ _s ]->{ $_[0] };
	$e = exists $p->{ $_[1] };
	$n = $p->{ $_[1] };
    } else {
	($e, $n) = $m->_get_path_node( @_ );
    }
    return undef unless $e;
    return ref $n ? $n->[ _ni ] : $n;
}

sub _get_path_count {
    my $m = shift;
    my $f = $m->[ _f ];
    my ($e, $n) = $m->_get_path_node( @_ );
    return undef unless $e && defined $n;
    return
	($f & _COUNT) ? $n->[ _nc ] :
	($f & _MULTI) ? scalar keys %{ $n->[ _nm ] } : 1;
}

sub __attr {
    my $m = shift;
    return unless @_ and ref $_[0] && @{ $_[0] };
    Graph::__carp_confess(sprintf
		  "Graph::AdjacencyMap::Heavy: arguments %d expected %d\n",
		  scalar @{ $_[0] }, $m->[ _a ])
	if @{ $_[0] } != $m->[ _a ];
    my $f = $m->[ _f ];
    if (@{ $_[0] } > 1 && ($f & _UNORDUNIQ)) {
	if (($f & _UNORDUNIQ) == _UNORD && @{ $_[0] } == 2) {
	    @{ $_[0] } = sort @{ $_[0] }
	} else { $m->__arg(\@_) }
    }
}

sub _get_id_path {
    my ($m, $i) = @_;
    my $p = defined $i ? $m->[ _i ]->{ $i } : undef;
    return defined $p ? @$p : ( );
}

sub del_path {
    my $m = shift;
    my $f = $m->[ _f ];
    my ($e, $n, $p, $k, $l) = $m->__get_path_node( @_ );
    return unless $e;
    my $c = ($f & _COUNT) ? --$n->[ _nc ] : 0;
    if ($c == 0) {
	delete $m->[ _i ]->{ ref $n ? $n->[ _ni ] : $n };
	delete $p->[-1]->{ $l };
	while (@$p && @$k && keys %{ $p->[-1]->{ $k->[-1] } } == 0) {
	    delete $p->[-1]->{ $k->[-1] };
	    pop @$p;
	    pop @$k;
	}
    }
    return 1;
}

# $vertices = hash index => array-ref of vertex-names
# $this_path = tree-hash of vertex-name to next depth or leaf=index
sub _rename_path {
    my ($from, $to, $vertices, $this_path, $depth, $found) = @_;
    if (!ref $this_path) {
	# at a leaf
	return if !defined $found;
	$vertices->{ $this_path }[ $found ] = $to;
	return;
    }
    my %recurse = map +($_ => undef), keys %$this_path;
    if (exists $recurse{ $from }) {
	delete $recurse{ $from };
	my $tp = $this_path->{ $to } = delete $this_path->{ $from };
	# recurse with $found defined
	_rename_path($from, $to, $vertices, $tp, $depth + 1, $depth);
    }
    # recurse with $found not further specified
    _rename_path($from, $to, $vertices, $this_path->{ $_ }, $depth + 1, $found)
	for keys %recurse;
}

sub rename_path {
    my ($m, $from, $to) = @_;
    return 1 if $m->[ _a ] > 1; # arity > 1, all integers, no names
    for my $node_length (0..$#{$m->[ _s ]}) {
	next unless my $this_path = $m->[ _s ][$node_length];
	_rename_path($from, $to, $m->[ _i ], $this_path, 0);
    }
}

sub del_path_by_multi_id {
    my $m = shift;
    my $f = $m->[ _f ];
    my $id = pop;
    my ($e, $n, $p, $k, $l) = $m->__get_path_node( @_ );
    return unless $e;
    delete $n->[ _nm ]->{ $id };
    unless (keys %{ $n->[ _nm ] }) {
	delete $m->[ _i ]->{ $n->[ _ni ] };
	delete $p->[-1]->{ $l };
	while (@$p && @$k && keys %{ $p->[-1]->{ $k->[-1] } } == 0) {
	    delete $p->[-1]->{ $k->[-1] };
	    pop @$p;
	    pop @$k;
	}
    }
    return 1;
}

sub paths {
    my $m = shift;
    return values %{ $m->[ _i ] } if defined $m->[ _i ];
    wantarray ? ( ) : 0;
}

1;
__END__
