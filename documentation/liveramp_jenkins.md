# LiveRamp Jenkins Setup

As mentioned in [setup.md](setup.md), we invoke Docker and KDT commands to
generate artifacts as part of our deployment pipeline.

Below are instructions for how to include credentials in Jenkins that are
required for pushing artifacts to Artifactory, AWS ECR, and GCP GCR.

The Docker build and KDT commands will use these credentials and the commands
should be run somewhere in your build.

<!-- TOC -->

- [LiveRamp Jenkins Setup](#liveramp-jenkins-setup)
  - [Java Projects](#java-projects)
    - [Jenkinsfiles Configuration](#jenkinsfiles-configuration)
    - [Removing Deprecated pom.xml Configuration](#removing-deprecated-pomxml-configuration)
    - [Further Java References](#further-java-references)
  - [Non-Java projects](#non-java-projects)
    - [Jenkinsfile Configuration](#jenkinsfile-configuration)
    - [Jenkins UI Configuration](#jenkins-ui-configuration)

<!-- /TOC -->

## Java Projects

### Jenkinsfiles Configuration
1. See steps in [MasterRepos/jenkins_pipelines](https://git.***REMOVED***/MasterRepos/jenkins_pipelines/blob/master/README.md) to add a Jenkinsfile to your repository

Note: The project name in the KDT deploy will change to using the Jenkinsfile. The new name will be `project=MasterRepos/${repository}/${branch_name}`.
This can be found at the top of the Jenkins job that was run for the desired build.

Cross reference the KB page
[Jenkinsfiles](https://liveramp.atlassian.net/wiki/spaces/CI/pages/138249012/Jenkinsfiles)

### Removing Deprecated pom.xml Configuration

1. Run `bundle update` in the root directory of the project
2. Follow the steps in [MasterRepos/jenkins_pipelines](https://git.***REMOVED***/MasterRepos/jenkins_pipelines/blob/master/README.md) to add a Jenkinsfile to your repository
3. In all the pom.xmls within the project remove any occurence of the below:

```diff
-    <skip.kdt.docker>false</skip.kdt.docker>
-    <skip.kdt.kubernetes>false</skip.kdt.kubernetes>
-    <docker.images>${project.artifactId}</docker.images>
```

4. If it is a multi-module project:
   * In the root directory, run the following
   ```bash
     mv *_kubernetes/kubernetes .
     mv *_kubernetes/Gemfile .
     rm -rf *_kubernetes
   ```
   * In pom.xml remove any references to the `*_kubernetes` module
   * Now the structure of the root directory and files should mimic that of a single module repository
5. Run `bundle install` to verify

### Further Java References

Cross reference the KB page
[Migrating Backend Applications to Kubernetes](https://liveramp.atlassian.net/wiki/spaces/CI/pages/98096573/Migrating+Backend+Applications+to+Kubernetes)
with `java_project_tools`, or `jpt`.

## Non-Java projects

### Jenkinsfile Configuration

TBD

### Jenkins UI Configuration
Below are Jenkins build steps required for configuration in the Jenkins UI.

For examples of Jenkins configurations, see below.
* [ingestion_file_locator](https://jenkins.***REMOVED***/job/ingestion_file_locator/configure)
* [ingestion_file_locator_prs](https://jenkins.***REMOVED***/job/ingestion_file_locator_prs/configure)

1. Jenkins credentials are required for Github auth on `docker2` machines below.
  * Under Credentials > Source Code Management > Git, select `rapleaf (RSA,  github)`.

2. Jenkins credentials are required to publish your project's images to AWS ECR
and your project's deploy artifacts to Artifactory. See the image below and instructions.

![Jenkins Artifactory upload](images/jenkins_build.png)

  * Under Build Environment, check Use secret text(s) or file(s).
  * Under Bindings, select username and password (separated) with
  `AWS_ACCESS_KEY_ID` as the Username Variable,
  `AWS_SECRET_ACCESS_KEY` as the Password Variable, and
  `.../****** (AWS svc-jenkins-docker credentials for ECR)` selected as the specific
  credentials. See above.
  * Under Bindings, select username and password (separated) with
  `ARTIFACTORY_USERNAME` as the Username Variable,
  `ARTIFACTORY_PASSWORD` as the Password Variable, and
  `jenkins_publisher/****** (***REMOVED***)` selected as the specific
  credentials. See above.
