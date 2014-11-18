package MDOM::Element;

=pod

=head1 NAME

MDOM::Element - The abstract Element class, a base for all source objects

=head1 INHERITANCE

  MDOM::Element is the root of the PDOM tree

=head1 DESCRIPTION

The abstract C<MDOM::Element> serves as a base class for all source-related
objects, from a single whitespace token to an entire document. It provides
a basic set of methods to provide a common interface and basic
implementations.

=head1 METHODS

=cut

use strict;
use Scalar::Util 'refaddr';
use Params::Util '_INSTANCE',
                 '_ARRAY';
use MDOM::Node      ();
use Clone           ();
use List::MoreUtils ();
use overload 'bool' => sub () { 1 },
             '""'   => 'content',
             '=='   => '__equals',
             '!='   => '__nequals',
             'eq'   => '__eq',
             'ne'   => '__ne';

use vars qw{$VERSION $errstr %_PARENT};
BEGIN {
	$VERSION = '0.007';
	$errstr  = '';

	# Master Child -> Parent index
	%_PARENT = ();
}





#####################################################################
# General Properties

=pod

=head2 significant

Because we treat whitespace and other non-code items as Tokens (in order to
be able to "round trip" the L<MDOM::Document> back to a file) the
C<significant> method allows us to distinguish between tokens that form a
part of the code, and tokens that aren't significant, such as whitespace,
POD, or the portion of a file after (and including) the C<__END__> token.

Returns true if the Element is significant, or false it not.

=cut

### XS -> MDOM/XS.xs:_MDOM_Element__significant 0.845+
sub significant { 1 }

=head2 lineno

Accessor for current line number.

=cut

sub lineno {
    $_[0]->{lineno};
}

=pod

=head2 class

The C<class> method is provided as a convenience, and really does nothing
more than returning C<ref($self)>. However, some people have found that
they appreciate the laziness of C<$Foo-E<gt>class eq 'whatever'>, so I
have caved to popular demand and included it.

Returns the class of the Element as a string

=cut

sub class { ref($_[0]) }

=pod

=head2 tokens

The C<tokens> method returns a list of L<MDOM::Token> objects for the
Element, essentially getting back that part of the document as if it had
not been lexed.

This also means there are no Statements and no Structures in the list,
just the Token classes.

=cut

sub tokens { $_[0] }

=pod

=head2 content

For B<any> C<MDOM::Element>, the C<content> method will reconstitute the
base code for it as a single string. This method is also the method used
for overloading stringification. When an Element is used in a double-quoted
string for example, this is the method that is called.

B<WARNING:>

You should be aware that because of the way that here-docs are handled, any
here-doc content is not included in C<content>, and as such you should
B<not> eval or execute the result if it contains any L<MDOM::Token::HereDoc>.

The L<MDOM::Document> method C<serialize> should be used to stringify a PDOM
document into something that can be executed as expected.

Returns the basic code as a string (excluding here-doc content).

=cut

### XS -> MDOM/XS.xs:_MDOM_Element__content 0.900+
sub content { '' }


#####################################################################
# Naigation Methods

=pod

=head2 parent

Elements themselves are not intended to contain other Elements, that is
left to the L<MDOM::Node> abstract class, a subclass of C<MDOM::Element>.
However, all Elements can be contained B<within> a parent Node.

If an Element is within a parent Node, the C<parent> method returns the
Node.

=cut

sub parent { $_PARENT{refaddr $_[0]} }

=pod

=head2 statement

For a C<MDOM::Element> that is contained (at some depth) within a
L<MDOM::Statment>, the C<statement> method will return the first parent
Statement object lexically 'above' the Element.

Returns a L<MDOM::Statement> object, which may be the same Element if the
Element is itself a L<MDOM::Statement> object.

Returns false if the Element is not within a Statement and is not itself
a Statement.

=cut

sub statement {
	my $cursor = shift;
	while ( ! _INSTANCE($cursor, 'MDOM::Statement') ) {
		$cursor = $_PARENT{refaddr $cursor} or return '';
	}
	$cursor;
}

=pod

=head2 top

For a C<MDOM::Element> that is contained within a PDOM tree, the C<top> method
will return the top-level Node in the tree. Most of the time this should be
a L<MDOM::Document> object, however this will not always be so. For example,
if a subroutine has been removed from its Document, to be moved to another
Document.

Returns the top-most PDOM object, which may be the same Element, if it is
not within any parent PDOM object.

=cut

sub top {
	my $cursor = shift;
	while ( my $parent = $_PARENT{refaddr $cursor} ) {
		$cursor = $parent;
	}
	$cursor;
}

=pod

=head2 document

For an Element that is contained within a L<MDOM::Document> object,
the C<document> method will return the top-level Document for the Element.

Returns the L<MDOM::Document> for this Element, or false if the Element is not
contained within a Document.

=cut

sub document {
	my $top = shift->top;
	_INSTANCE($top, 'MDOM::Document') and $top;
}

=pod

=head2 next_sibling

All L<MDOM::Node> objects (specifically, our parent Node) contain a number of
C<MDOM::Element> objects. The C<next_sibling> method returns the C<MDOM::Element>
immediately after the current one, or false if there is no next sibling.

=cut

sub next_sibling {
	my $self     = shift;
	my $parent   = $_PARENT{refaddr $self} or return '';
	my $key      = refaddr $self;
	my $elements = $parent->{children};
	my $position = List::MoreUtils::firstidx {
		refaddr $_ == $key
		} @$elements;
	$elements->[$position + 1] || '';
}

=pod

=head2 snext_sibling

As per the other 's' methods, the C<snext_sibling> method returns the next
B<significant> sibling of the C<MDOM::Element> object.

Returns a C<MDOM::Element> object, or false if there is no 'next' significant
sibling.

=cut

sub snext_sibling {
	my $self     = shift;
	my $parent   = $_PARENT{refaddr $self} or return '';
	my $key      = refaddr $self;
	my $elements = $parent->{children};
	my $position = List::MoreUtils::firstidx {
		refaddr $_ == $key
		} @$elements;
	while ( defined(my $it = $elements->[++$position]) ) {
		return $it if $it->significant;
	}
	'';
}

=pod

=head2 previous_sibling

All L<MDOM::Node> objects (specifically, our parent Node) contain a number of
C<MDOM::Element> objects. The C<previous_sibling> method returns the Element
immediately before the current one, or false if there is no 'previous'
C<MDOM::Element> object.

=cut

sub previous_sibling {
	my $self     = shift;
	my $parent   = $_PARENT{refaddr $self} or return '';
	my $key      = refaddr $self;
	my $elements = $parent->{children};
	my $position = List::MoreUtils::firstidx {
		refaddr $_ == $key
		} @$elements;
	$position and $elements->[$position - 1] or '';
}

=pod

=head2 sprevious_sibling

As per the other 's' methods, the C<sprevious_sibling> method returns
the previous B<significant> sibling of the C<MDOM::Element> object.

Returns a C<MDOM::Element> object, or false if there is no 'previous' significant
sibling.

=cut

sub sprevious_sibling {
	my $self     = shift;
	my $parent   = $_PARENT{refaddr $self} or return '';
	my $key      = refaddr $self;
	my $elements = $parent->{children};
	my $position = List::MoreUtils::firstidx {
		refaddr $_ == $key
		} @$elements;
	while ( $position-- and defined(my $it = $elements->[$position]) ) {
		return $it if $it->significant;
	}
	'';
}

=pod

=head2 first_token

As a support method for higher-order algorithms that deal specifically with
tokens and actual Perl content, the C<first_token> method finds the first
MDOM::Token object within or equal to this one.

That is, if called on a L<MDOM::Node> subclass, it will descend until it
finds a L<MDOM::Token>. If called on a L<MDOM::Token> object, it will return
the same object.

Returns a L<MDOM::Token> object, or dies on error (which should be extremely
rare and only occur if an illegal empty L<MDOM::Statement> exists below the
current Element somewhere.

=cut

sub first_token {
	my $cursor = shift;
	while ( $cursor->isa('MDOM::Node') ) {
		$cursor = $cursor->first_element
		or die "Found empty MDOM::Node while getting first token";
	}
	$cursor;
}


=pod

=head2 last_token

As a support method for higher-order algorithms that deal specifically with
tokens and actual Perl content, the C<last_token> method finds the last
MDOM::Token object within or equal to this one.

That is, if called on a L<MDOM::Node> subclass, it will descend until it
finds a L<MDOM::Token>. If called on a L<MDOM::Token> object, it will return
the itself.

Returns a L<MDOM::Token> object, or dies on error (which should be extremely
rare and only occur if an illegal empty L<MDOM::Statement> exists below the
current Element somewhere.

=cut

sub last_token {
	my $cursor = shift;
	while ( $cursor->isa('MDOM::Node') ) {
		$cursor = $cursor->last_element
		or die "Found empty MDOM::Node while getting first token";
	}
	$cursor;
}

=pod

=head2 next_token

As a support method for higher-order algorithms that deal specifically with
tokens and actual Perl content, the C<next_token> method finds the
L<MDOM::Token> object that is immediately after the current Element, even if
it is not within the same parent L<MDOM::Node> as the one for which the
method is being called.

Note that this is B<not> defined as a L<MDOM::Token>-specific method,
because it can be useful to find the next token that is after, say, a
L<MDOM::Statement>, although obviously it would be useless to want the
next token after a L<MDOM::Document>.

Returns a L<MDOM::Token> object, or false if there are no more tokens after
the Element.

=cut

sub next_token {
	my $cursor = shift;

	# Find the next element, going upwards as needed
	while ( 1 ) {
		my $element = $cursor->next_sibling;
		if ( $element ) {
			return $element if $element->isa('MDOM::Token');
			return $element->first_token;
		}
		$cursor = $cursor->parent or return '';
		if ( $cursor->isa('MDOM::Structure') and $cursor->finish ) {
			return $cursor->finish;
		}
	}
}

=pod

=head2 previous_token

As a support method for higher-order algorithms that deal specifically with
tokens and actual Perl content, the C<previous_token> method finds the
L<MDOM::Token> object that is immediately before the current Element, even
if it is not within the same parent L<MDOM::Node> as this one.

Note that this is not defined as a L<MDOM::Token>-only method, because it can
be useful to find the token is before, say, a L<MDOM::Statement>, although
obviously it would be useless to want the next token before a
L<MDOM::Document>.

Returns a L<MDOM::Token> object, or false if there are no more tokens before
the C<Element>.

=cut

sub previous_token {
	my $cursor = shift;

	# Find the previous element, going upwards as needed
	while ( 1 ) {
		my $element = $cursor->previous_sibling;
		if ( $element ) {
			return $element if $element->isa('MDOM::Token');
			return $element->last_token;
		}
		$cursor = $cursor->parent or return '';
		if ( $cursor->isa('MDOM::Structure') and $cursor->start ) {
			return $cursor->start;
		}
	}
}





#####################################################################
# Manipulation

=pod

=head2 clone

As per the L<Clone> module, the C<clone> method makes a perfect copy of
an Element object. In the generic case, the implementation is done using
the L<Clone> module's mechanism itself. In higher-order cases, such as for
Nodes, there is more work involved to keep the parent-child links intact.

=cut

sub clone {
	Clone::clone(shift);
}

=pod

=head2 insert_before @Elements

The C<insert_before> method allows you to insert lexical perl content, in
the form of C<MDOM::Element> objects, before the calling C<Element>. You
need to be very careful when modifying perl code, as it's easy to break
things.

In its initial incarnation, this method allows you to insert a single
Element, and will perform some basic checking to prevent you inserting
something that would be structurally wrong (in PDOM terms).

In future, this method may be enhanced to allow the insertion of multiple
Elements, inline-parsed code strings or L<MDOM::Document::Fragment> objects.

Returns true if the Element was inserted, false if it can not be inserted,
or C<undef> if you do not provide a L<MDOM::Element> object as a parameter.

=cut

sub __insert_before {
	my $self = shift;
	$self->parent->__insert_before_child( $self, @_ );
}

=pod

=head2 insert_after @Elements

The C<insert_after> method allows you to insert lexical perl content, in
the form of C<MDOM::Element> objects, after the calling C<Element>. You need
to be very careful when modifying perl code, as it's easy to break things.

In its initial incarnation, this method allows you to insert a single
Element, and will perform some basic checking to prevent you inserting
something that would be structurally wrong (in PDOM terms).

In future, this method may be enhanced to allow the insertion of multiple
Elements, inline-parsed code strings or L<MDOM::Document::Fragment> objects.

Returns true if the Element was inserted, false if it can not be inserted,
or C<undef> if you do not provide a L<MDOM::Element> object as a parameter.

=cut

sub __insert_after {
	my $self = shift;
	$self->parent->__insert_after_child( $self, @_ );
}

=pod

=head2 remove

For a given C<MDOM::Element>, the C<remove> method will remove it from its
parent B<intact>, along with all of its children.

Returns the C<Element> itself as a convenience, or C<undef> if an error
occurs while trying to remove the C<Element>.

=cut

sub remove {
	my $self   = shift;
	my $parent = $self->parent or return $self;
	$parent->remove_child( $self );
}

=pod

=head2 delete

For a given C<MDOM::Element>, the C<remove> method will remove it from its
parent, immediately deleting the C<Element> and all of its children (if it
has any).

Returns true if the C<Element> was successfully deleted, or C<undef> if
an error occurs while trying to remove the C<Element>.

=cut

sub delete {
	$_[0]->remove or return undef;
	$_[0]->DESTROY;
	1;
}

=pod

=head2 replace $Element

Although some higher level class support more exotic forms of replace,
at the basic level the C<replace> method takes a single C<Element> as
an argument and replaces the current C<Element> with it.

To prevent accidental damage to code, in this initial implementation the
replacement element B<must> be of the same class (or a subclass) as the
one being replaced.

=cut

sub replace {
	my $self    = ref $_[0] ? shift : return undef;
	my $Element = _INSTANCE(shift, ref $self) or return undef;
	die "The ->replace method has not yet been implemented";
}

=pod

=head2 location

If the Element exists within a L<MDOM::Document> that has
indexed the Element locations using C<MDOM::Document::index_locations>, the
C<location> method will return the location of the first character of the
Element within the Document.

Returns the location as a reference to a three-element array in the form
C<[ $line, $rowchar, $col ]>. The values are in a human format, with the
first character of the file located at C<[ 1, 1, 1 ]>. 

The second and third numbers are similar, except that the second is the
literal horizontal character, and the third is the visual column, taking
into account tabbing.

Returns C<undef> on error, or if the L<MDOM::Document> object has not been indexed.

=cut

sub location {
	my $self = shift;
	unless ( exists $self->{_location} ) {
		# Are we inside a normal document?
		my $Document = $self->document or return undef;
		if ( $Document->isa('MDOM::Document::Fragment') ) {
			# Because they can't be serialized, document fragments
			# do not support the concept of location.
			return undef;
		}

		# Generate the locations. If they need one location, then
		# the chances are they'll want more, and it's better that
		# everything is already pre-generated.
		$Document->index_locations or return undef;
		unless ( exists $self->{_location} ) {
			# erm... something went very wrong here
			return undef;
		}
	}

	# Return a copy, not the original
	return [ @{$self->{_location}} ];
}

# Although flush_locations is only publically a Document-level method,
# we are able to implement it at an Element level, allowing us to
# selectively flush only the part of the document that occurs after the
# element for which the flush is called.
sub _flush_locations {
	my $self  = shift;
	unless ( $self == $self->top ) {
		return $self->top->_flush_locations( $self );
	}

	# Get the full list of all Tokens
	my @Tokens = $self->tokens;

	# Optionally allow starting from an arbitrary element (or rather,
	# the first Token equal-to-or-within an arbitrary element)
	if ( _INSTANCE($_[0], 'MDOM::Element') ) {
		my $start = shift->first_token;
		while ( my $Token = shift @Tokens ) {
			return 1 unless $Token->{_location};
			next unless refaddr($Token) == refaddr($start);

			# Found the start. Flush it's location
			delete $$Token->{_location};
			last;
		}
	}

	# Iterate over any remaining Tokens and flush their location
	foreach my $Token ( @Tokens ) {
		delete $Token->{_location};
	}

	1;
}





#####################################################################
# XML Compatibility Methods

sub _xml_name {
	my $class = ref $_[0] || $_[0];
	my $name  = lc join( '_', split /::/, $class );
	substr($name, 4);
}

sub _xml_attr {
	return {};
}

sub _xml_content {
	defined $_[0]->{content} ? $_[0]->{content} : '';
}





#####################################################################
# Internals

# Set the error string
sub _error {
	$errstr = $_[1];
	undef;
}

# Clear the error string
sub _clear {
	$errstr = '';
	$_[0];
}

# Being DESTROYed in this manner, rather than by an explicit
# ->delete means our reference count has probably fallen to zero.
# Therefore we don't need to remove ourselves from our parent,
# just the index ( just in case ).
### XS -> MDOM/XS.xs:_MDOM_Element__DESTROY 0.900+
sub DESTROY { delete $_PARENT{refaddr $_[0]} }

# Operator overloads
sub __equals  { ref $_[1] and refaddr($_[0]) == refaddr($_[1]) }
sub __nequals { !__equals(@_) }
sub __eq {
	my $self  = _INSTANCE($_[0], 'MDOM::Element') ? $_[0]->content : $_[0];
	my $other = _INSTANCE($_[1], 'MDOM::Element') ? $_[1]->content : $_[1];
	$self eq $other;
}
sub __ne { !__eq(@_) }

1;

=pod

=head1 TO DO

It would be nice if C<location> could be used in an ad-hoc manner. That is,
if called on an Element within a Document that has not been indexed, it will
do a one-off calculation to find the location. It might be very painful if
someone started using it a lot, without remembering to index the document,
but it would be handy for things that are only likely to use it once, such
as error handlers.

=head1 SUPPORT

See the L<support section|MDOM/SUPPORT> in the main module.

=head1 AUTHOR

Adam Kennedy E<lt>adamk@cpan.orgE<gt>

=head1 COPYRIGHT

Copyright 2001 - 2006 Adam Kennedy.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
