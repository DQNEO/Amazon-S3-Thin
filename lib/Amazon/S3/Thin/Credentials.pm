package Amazon::S3::Thin::Credentials;

=head1 NAME

Amazon::S3::Thin::Credentials - AWS credentials data container

=head1 SYNOPSIS

    my $credentials = Amazon::S3::Thin::Credentials->new(
        $aws_access_key_id, $aws_secret_access_key,
        # optional:
        $aws_session_token
    );
    
    my $key = $credentials->access_key_id();
    my $secret = $credentials->secret_access_key();
    my $session_token = $credentials->session_token();

1;

=head1 DESCRIPTION

This module contains AWS credentials and provide getters to the data.

    # Load from arguments
    my $creds = Amazon::S3::Thin::Credentials->new($access_key, $secret_key, $session_token);

    # Load from environment
    my $creds = Amazon::S3::Thin::Credentials->from_env;

    # Load from instance profile
    my $creds = Amazon::S3::Thin::Credentials->from_instance(role => 'foo', version => 2);

=cut

use strict;
use warnings;

use Carp;
use JSON::PP ();
use LWP::UserAgent;

my $JSON = JSON::PP->new->utf8->canonical;

sub new {
    my ($class, $key, $secret, $session_token) = @_;
    my $self = {
        key => $key,
        secret => $secret,
        session_token => $session_token,
    };
    return bless $self, $class;
}

=head2 from_env()

Instantiate C<Amazon::S3::Thin::Credentials> and attempts to populate the credentials from
current environment.

Croaks if either AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY are not set but supports the
optional AWS_SESSION_TOKEN variable.

    my $creds = Amazon::S3::Thin::Credentials->from_env;

=cut

sub from_env {
    my ($class) = @_;

    # Check the environment is configured
    croak "AWS_ACCESS_KEY_ID is not set" unless $ENV{AWS_ACCESS_KEY_ID};
    croak "AWS_SECRET_ACCESS_KEY is not set" unless $ENV{AWS_SECRET_ACCESS_KEY};

    my $self = {
        key => $ENV{AWS_ACCESS_KEY_ID},
        secret => $ENV{AWS_SECRET_ACCESS_KEY},
        session_token => $ENV{AWS_SESSION_TOKEN}
    };
    return bless $self, $class;
}

=head2 from_metadata()

Instantiate C<Amazon::S3::Thin::Credentials> and attempts to populate the credentials from
the L<EC2 metadata service|https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html>. An instance can have multiple IAM
roles applied so you may optionally specify a role, otherwise the first one will be used.

In November 2019 AWS released L<version 2|https://aws.amazon.com/blogs/security/defense-in-depth-open-firewalls-reverse-proxies-ssrf-vulnerabilities-ec2-instance-metadata-service/> of the instance metadata service which
is more secure against Server Side Request Forgery attacks. Using v2 is highly recommended thus
it is the default here.

    my $creds = Amazon::S3::Thin::Credentials->from_instance(
        role => 'foo',      # The name of the IAM role on the instance
        version => 2        # Metadata service version - either 1 or 2
    );

=cut

sub from_metadata {
    my ($class, $args) = @_;

    my $ua = $args->{ua} // LWP::UserAgent->new;

    # Default to the more secure v2 metadata provider
    if (!$args->{version} or $args->{version} != 1) {
        my $res = $ua->put('http://169.254.169.254/latest/api/token', 'X-aws-ec2-metadata-token-ttl-seconds' => 90);
        croak 'Error retreiving v2 token from metadata provider: ' . $res->decoded_content
            unless $res->is_success;

        $ua->default_header('X-aws-ec2-metadata-token' => $res->decoded_content);
    }

    return _instance_metadata($ua, $args->{role});
}

sub _instance_metadata {
    my ($ua, $role) = @_;

    my $res = $ua->get('http://169.254.169.254/latest/meta-data/iam/security-credentials');
    croak 'Error querying metadata service for roles: ' . $res->decoded_content unless $res->is_success;

    my @roles = split /\n/, $res->decoded_content;
    return unless @roles > 0;

    my $target_role = (defined $role and grep { $role eq $_ } @roles)
        ? $role
        : $roles[0];

    my $cred = $ua->get('http://169.254.169.254/latest/meta-data/iam/security-credentials/' . $target_role);
    croak 'Error querying metadata service for credentials: ' . $cred->decoded_content unless $cred->is_success;

    my $obj = eval { $JSON->decode($cred->decoded_content) };
    croak "Invalid data returned from metadata service: $@" if $@;

    return __PACKAGE__->new($obj->{AccessKeyId}, $obj->{SecretAccessKey}, $obj->{Token});
}

=head2 access_key_id()

Returns access_key_id

=cut

sub access_key_id {
    my $self = shift;
    return $self->{key};
}

=head2 secret_access_key()

Returns secret_access_key

=cut
    
sub secret_access_key {
    my $self = shift;
    return $self->{secret};
}

=head2 session_token()

Returns session_token

=cut

sub session_token {
    my $self = shift;
    return $self->{session_token};
}

1;
