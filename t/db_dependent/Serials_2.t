#!/usr/bin/perl
use Modern::Perl;

use Test::More tests => 37;

use MARC::Record;

use C4::Biblio qw( AddBiblio );
use C4::Members qw( AddMember );
use t::lib::Mocks;
use_ok('C4::Serials');
use_ok('C4::Budgets');

# Mock userenv
local $SIG{__WARN__} = sub { warn $_[0] unless $_[0] =~ /redefined/ };
my $userenv;
*C4::Context::userenv = \&Mock_userenv;

my $dbh = C4::Context->dbh;
$dbh->{AutoCommit} = 0;
$dbh->{RaiseError} = 1;


my $supplierlist=eval{GetSuppliersWithLateIssues()};
ok(length($@)==0,"No SQL problem in GetSuppliersWithLateIssues");

my $record = MARC::Record->new();
$record->append_fields(
    MARC::Field->new( '952', '0', '0', a => 'CPL', b => 'CPL' )
);
my ( $biblionumber, $biblioitemnumber ) = C4::Biblio::AddBiblio($record, '');

my $my_branch = 'CPL';
my $another_branch = 'MPL';
my $budgetid;
my $bpid = AddBudgetPeriod({
    budget_period_startdate => '2015-01-01',
    budget_period_enddate   => '2015-12-31',
    budget_description      => "budget desc"
});

my $budget_id = AddBudget({
    budget_code        => "ABCD",
    budget_amount      => "123.132",
    budget_name        => "Périodiques",
    budget_notes       => "This is a note",
    budget_description => "Serials",
    budget_active      => 1,
    budget_period_id   => $bpid
});

my $subscriptionid_from_my_branch = NewSubscription(
    undef,      $my_branch,     undef, undef, $budget_id, $biblionumber,
    '2013-01-01', undef, undef, undef,  undef,
    undef,      undef,  undef, undef, undef, undef,
    1,          "notes",undef, '2013-01-01', undef, undef,
    undef,       undef,  0,    "intnotes",  0,
    undef, undef, 0,          undef,         '2013-12-31', 0
);
die unless $subscriptionid_from_my_branch;

my $subscriptionid_from_another_branch = NewSubscription(
    undef,      $another_branch,     undef, undef, $budget_id, $biblionumber,
    '2013-01-01', undef, undef, undef,  undef,
    undef,      undef,  undef, undef, undef, undef,
    1,          "notes",undef, '2013-01-01', undef, undef,
    undef,       undef,  0,    "intnotes",  0,
    undef, undef, 0,          undef,         '2013-12-31', 0
);


my $subscription_from_my_branch = GetSubscription( $subscriptionid_from_my_branch );
is( C4::Serials::can_edit_subscription($subscription_from_my_branch), 0, "cannot edit a subscription without userenv set");

my $userid = 'my_userid';
my $borrowernumber = C4::Members::AddMember(
    firstname =>  'my fistname',
    surname => 'my surname',
    categorycode => 'S',
    branchcode => $my_branch,
    userid => $userid,
);

$userenv = { flags => 1, id => $borrowernumber, branch => '' };

# Can edit a subscription

is( C4::Serials::can_edit_subscription($subscription_from_my_branch), 1, "User can edit a subscription with an empty branchcode");

my $subscription_from_another_branch = GetSubscription( $subscriptionid_from_another_branch );

$userenv->{id} = $userid;
$userenv->{branch} = $my_branch;

# Branches are independent
t::lib::Mocks::mock_preference( "IndependentBranches", 1 );
set_flags( 'superlibrarian', $borrowernumber );
is( C4::Serials::can_edit_subscription($subscription_from_my_branch), 1,
"With IndependentBranches, superlibrarian can edit a subscription from his branch"
);
is( C4::Serials::can_edit_subscription($subscription_from_another_branch), 1,
"With IndependentBranches, superlibrarian can edit a subscription from another branch"
);
is( C4::Serials::can_show_subscription($subscription_from_my_branch), 1,
"With IndependentBranches, superlibrarian can show a subscription from his branch"
);
is( C4::Serials::can_show_subscription($subscription_from_another_branch), 1,
"With IndependentBranches, superlibrarian can show a subscription from another branch"
);

set_flags( 'superserials', $borrowernumber );
is( C4::Serials::can_edit_subscription($subscription_from_my_branch), 1,
"With IndependentBranches, superserials can edit a subscription from his branch"
);
is( C4::Serials::can_edit_subscription($subscription_from_another_branch), 1,
"With IndependentBranches, superserials can edit a subscription from another branch"
);
is( C4::Serials::can_show_subscription($subscription_from_my_branch), 1,
"With IndependentBranches, superserials can show a subscription from his branch"
);
is( C4::Serials::can_show_subscription($subscription_from_another_branch), 1,
"With IndependentBranches, superserials can show a subscription from another branch"
);


set_flags( 'edit_subscription', $borrowernumber );
is( C4::Serials::can_edit_subscription($subscription_from_my_branch), 1,
"With IndependentBranches, edit_subscription can edit a subscription from his branch"
);
is( C4::Serials::can_edit_subscription($subscription_from_another_branch), 0,
"With IndependentBranches, edit_subscription cannot edit a subscription from another branch"
);
is( C4::Serials::can_show_subscription($subscription_from_my_branch), 1,
"With IndependentBranches, show_subscription can show a subscription from his branch"
);
is( C4::Serials::can_show_subscription($subscription_from_another_branch), 0,
"With IndependentBranches, show_subscription cannot show a subscription from another branch"
);

set_flags( 'renew_subscription', $borrowernumber );
is( C4::Serials::can_edit_subscription($subscription_from_my_branch), 0,
"With IndependentBranches, renew_subscription cannot edit a subscription from his branch"
);
is( C4::Serials::can_edit_subscription($subscription_from_another_branch), 0,
"With IndependentBranches, renew_subscription cannot edit a subscription from another branch"
);
is( C4::Serials::can_show_subscription($subscription_from_my_branch), 1,
"With IndependentBranches, renew_subscription can show a subscription from his branch"
);
is( C4::Serials::can_show_subscription($subscription_from_another_branch), 0,
"With IndependentBranches, renew_subscription cannot show a subscription from another branch"
);


# Branches are not independent
t::lib::Mocks::mock_preference( "IndependentBranches", 0 );
set_flags( 'superlibrarian', $borrowernumber );
is( C4::Serials::can_edit_subscription($subscription_from_my_branch), 1,
"Without IndependentBranches, superlibrarian can edit a subscription from his branch"
);
is( C4::Serials::can_edit_subscription($subscription_from_another_branch), 1,
"Without IndependentBranches, superlibrarian can edit a subscription from another branch"
);
is( C4::Serials::can_show_subscription($subscription_from_my_branch), 1,
"Without IndependentBranches, superlibrarian can show a subscription from his branch"
);
is( C4::Serials::can_show_subscription($subscription_from_another_branch), 1,
"Without IndependentBranches, superlibrarian can show a subscription from another branch"
);

set_flags( 'superserials', $borrowernumber );
is( C4::Serials::can_edit_subscription($subscription_from_my_branch), 1,
"Without IndependentBranches, superserials can edit a subscription from his branch"
);
is( C4::Serials::can_edit_subscription($subscription_from_another_branch), 1,
"Without IndependentBranches, superserials can edit a subscription from another branch"
);
is( C4::Serials::can_show_subscription($subscription_from_my_branch), 1,
"Without IndependentBranches, superserials can show a subscription from his branch"
);
is( C4::Serials::can_show_subscription($subscription_from_another_branch), 1,
"Without IndependentBranches, superserials can show a subscription from another branch"
);

set_flags( 'edit_subscription', $borrowernumber );
is( C4::Serials::can_edit_subscription($subscription_from_my_branch), 1,
"Without IndependentBranches, edit_subscription can edit a subscription from his branch"
);
is( C4::Serials::can_edit_subscription($subscription_from_another_branch), 1,
"Without IndependentBranches, edit_subscription can edit a subscription from another branch"
);
is( C4::Serials::can_show_subscription($subscription_from_my_branch), 1,
"Without IndependentBranches, show_subscription can show a subscription from his branch"
);
is( C4::Serials::can_show_subscription($subscription_from_another_branch), 1,
"Without IndependentBranches, show_subscription can show a subscription from another branch"
);

set_flags( 'renew_subscription', $borrowernumber );
is( C4::Serials::can_edit_subscription($subscription_from_my_branch), 0,
"Without IndependentBranches, renew_subscription cannot edit a subscription from his branch"
);
is( C4::Serials::can_edit_subscription($subscription_from_another_branch), 0,
"Without IndependentBranches, renew_subscription cannot edit a subscription from another branch"
);
is( C4::Serials::can_show_subscription($subscription_from_my_branch), 1,
"Without IndependentBranches, renew_subscription cannot show a subscription from his branch"
);
is( C4::Serials::can_show_subscription($subscription_from_another_branch), 1,
"Without IndependentBranches, renew_subscription cannot show a subscription from another branch"
);

$dbh->rollback;

# C4::Context->userenv
sub Mock_userenv {
    return $userenv;
}

sub set_flags {
    my ( $flags, $borrowernumber ) = @_;
    my $superlibrarian_flags = 1;
    if ( $flags eq 'superlibrarian' ) {
        $dbh->do(
            q|
            UPDATE borrowers SET flags=? WHERE borrowernumber=?
        |, {}, $superlibrarian_flags, $borrowernumber
        );
        $userenv->{flags} = $superlibrarian_flags;
    }
    else {
        $dbh->do(
            q|
            UPDATE borrowers SET flags=? WHERE borrowernumber=?
        |, {}, 0, $borrowernumber
        );
        $userenv->{flags} = 0;
        my ( $module_bit, $code ) = ( '15', $flags );
        $dbh->do(
            q|
            DELETE FROM user_permissions where borrowernumber=?
        |, {}, $borrowernumber
        );

        $dbh->do(
            q|
            INSERT INTO user_permissions( borrowernumber, module_bit, code ) VALUES ( ?, ?, ? )
        |, {}, $borrowernumber, $module_bit, $code
        );
    }
}
