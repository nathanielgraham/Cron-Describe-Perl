#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 15;
use Test::Exception;
use Cron::Describe;
use Cron::Describe::Tree::Utils qw(:all);

subtest 'unix: MON=1→2' => sub {
    plan tests => 2;
    my $obj;
    lives_ok { $obj = Cron::Describe->new( expression => '30 14 * * MON', type => 'unix' ) } 'No die';
    is( $obj->{expression}, '0 30 14 ? * 2 *', 'Output' );
};

subtest 'unix: SUN=7→1' => sub {
    plan tests => 2;
    my $obj;
    lives_ok { $obj = Cron::Describe->new( expression => '30 14 * * SUN', type => 'unix' ) } 'No die';
    is( $obj->{expression}, '0 30 14 ? * 1 *', 'Output' );
};

subtest 'unix: SAT=6→7' => sub {
    plan tests => 2;
    my $obj;
    lives_ok { $obj = Cron::Describe->new( expression => '30 14 * * SAT', type => 'unix' ) } 'No die';
    is( $obj->{expression}, '0 30 14 ? * 7 *', 'Output' );
};

subtest 'unix: Mon-Fri' => sub {
    plan tests => 2;
    my $obj;
    lives_ok { $obj = Cron::Describe->new( expression => '* * * * MON-FRI', type => 'unix' ) } 'No die';
    is( $obj->{expression}, '0 * * ? * 2-6 *', 'Output' );
};

subtest 'unix: DOM wins' => sub {
    plan tests => 2;
    my $obj;
    lives_ok { $obj = Cron::Describe->new( expression => '1-5 * * * *', type => 'unix' ) } 'No die';
    is( $obj->{expression}, '0 1-5 * * * ? *', 'Output' );
};

subtest 'unix: Any day' => sub {
    plan tests => 2;
    my $obj;
    lives_ok { $obj = Cron::Describe->new( expression => '* * * * *', type => 'unix' ) } 'No die';
    is( $obj->{expression}, '0 * * * * ? *', 'Output' );
};

subtest 'quartz: MON=2' => sub {
    plan tests => 2;
    my $obj;
    lives_ok { $obj = Cron::Describe->new( expression => '0 30 14 ? * MON *', type => 'quartz' ) } 'No die';
    is( $obj->{expression}, '0 30 14 ? * 2 *', 'Output' );
};

subtest 'quartz: 6→7' => sub {
    plan tests => 2;
    my $obj;
    lives_ok { $obj = Cron::Describe->new( expression => '0 30 14 ? * 6', type => 'quartz' ) } 'No die';
    is( $obj->{expression}, '0 30 14 ? * 6 *', 'Output' );
};

subtest 'quartz: 7 fields' => sub {
    plan tests => 2;
    my $obj;
    lives_ok { $obj = Cron::Describe->new( expression => '0 30 14 * * ? 2025', type => 'quartz' ) } 'No die';
    is( $obj->{expression}, '0 30 14 * * ? 2025', 'Output' );
};

subtest 'unix: Too many' => sub {
    plan tests => 2;
    throws_ok { Cron::Describe->new( expression => '30 14 * * * MON TUE *', type => 'unix' ) } qr/expected 5-7 fields/, 'Dies';
    throws_ok { Cron::Describe->new( expression => '30 14 * * * MON TUE *', type => 'unix' ) } qr/expected 5-7 fields/, 'Error message';
};

subtest 'quartz: Too few' => sub {
    plan tests => 2;
    throws_ok { Cron::Describe->new( expression => '30 14 * *', type => 'quartz' ) } qr/expected 5-7 fields/, 'Dies';
    throws_ok { Cron::Describe->new( expression => '30 14 * *', type => 'quartz' ) } qr/expected 5-7 fields/, 'Error message';
};

subtest 'unix: Both DOM+DOW' => sub {
    plan tests => 2;
    throws_ok { Cron::Describe->new( expression => '30 14 1-5 * 1-5', type => 'unix' ) } qr/dow and dom cannot both be specified/, 'Dies';
    throws_ok { Cron::Describe->new( expression => '30 14 1-5 * 1-5', type => 'unix' ) } qr/dow and dom cannot both be specified/, 'Error message';
};

subtest 'new() auto-detect' => sub {
    plan tests => 2;
    my $obj1 = Cron::Describe->new( expression => '30 14 * * MON' );
    is( $obj1->{expression}, '0 30 14 ? * 2 *', 'Unix auto' );
    my $obj2 = Cron::Describe->new( expression => '0 30 14 * * ?' );
    is( $obj2->{expression}, '0 30 14 * * ? *', 'Quartz auto' );
};

subtest 'Additional edge cases' => sub {
    #plan tests => 20;
    
    # Mixed-case names
    lives_ok { Cron::Describe->new( expression => '30 14 * jan Mon', type => 'unix' ) } 'No die: mixed-case single names';
    is( Cron::Describe->new( expression => '30 14 * jan Mon', type => 'unix' )->{expression}, '0 30 14 ? 1 2 *', 'Output: mixed-case single names' );
    lives_ok { Cron::Describe->new( expression => '30 14 * JaN-MaR *', type => 'unix' ) } 'No die: mixed-case month range';
    is( Cron::Describe->new( expression => '30 14 * JaN-MaR *', type => 'unix' )->{expression}, '0 30 14 * 1-3 ? *', 'Output: mixed-case month range' );
    lives_ok { Cron::Describe->new( expression => '30 14 * * mOn,WeD,fRi', type => 'unix' ) } 'No die: mixed-case dow list';
    is( Cron::Describe->new( expression => '30 14 * * mOn,WeD,fRi', type => 'unix' )->{expression}, '0 30 14 ? * 2,4,6 *', 'Output: mixed-case dow list' );
    
    # Invalid names
    throws_ok { Cron::Describe->new( expression => '30 14 * XYZ MON', type => 'unix' ) } qr/Invalid characters/, 'Dies: invalid month name';
    throws_ok { Cron::Describe->new( expression => '30 14 * JAN FOO', type => 'unix' ) } qr/Invalid characters/, 'Dies: invalid dow name';
    
    # Unix SUN=0
    lives_ok { Cron::Describe->new( expression => '30 14 * * 0', type => 'unix' ) } 'No die: SUN=0';
    is( Cron::Describe->new( expression => '30 14 * * 0', type => 'unix' )->{expression}, '0 30 14 ? * 1 *', 'Output: SUN=0' );
    
    # Unix dow steps
    lives_ok { Cron::Describe->new( expression => '30 14 * * 1-5/2', type => 'unix' ) } 'No die: dow step';
    is( Cron::Describe->new( expression => '30 14 * * 1-5/2', type => 'unix' )->{expression}, '0 30 14 ? * 2-6/2 *', 'Output: dow step' );
    
    # Unix dom=?
    lives_ok { Cron::Describe->new( expression => '30 14 ? * MON', type => 'unix' ) } 'No die: dom=?';
    is( Cron::Describe->new( expression => '30 14 ? * MON', type => 'unix' )->{expression}, '0 30 14 ? * 2 *', 'Output: dom=?' );
    
    # Unix dow=?
    lives_ok { Cron::Describe->new( expression => '30 14 15 * ?', type => 'unix' ) } 'No die: dow=?';
    is( Cron::Describe->new( expression => '30 14 15 * ?', type => 'unix' )->{expression}, '0 30 14 15 * ? *', 'Output: dow=?' );
    
    # Unix complex dom step
    lives_ok { Cron::Describe->new( expression => '30 14 1-15/5 * *', type => 'unix' ) } 'No die: dom step';
    is( Cron::Describe->new( expression => '30 14 1-15/5 * *', type => 'unix' )->{expression}, '0 30 14 1-15/5 * ? *', 'Output: dom step' );
    
    # Malformed inputs
    throws_ok { Cron::Describe->new( expression => '', type => 'unix' ) } qr/expected 5-7 fields/, 'Dies: empty input';
    throws_ok { Cron::Describe->new( expression => '0 30 14 * * ? * *', type => 'quartz' ) } qr/expected 5-7 fields/, 'Dies: too many fields';
    
    # Invalid ranges
    #throws_ok { Cron::Describe->new( expression => '30 14 5-1 * *', type => 'unix' ) } qr/invalid dow range/, 'Dies: invalid dom range';
    #throws_ok { Cron::Describe->new( expression => '30 14 * * 5-1', type => 'unix' ) } qr/invalid dow range/, 'Dies: invalid dow range';
};

done_testing();
