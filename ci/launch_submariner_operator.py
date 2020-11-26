#!/bin/python3

"""Main CI job script for submariner tests."""

import os
import subprocess
import time

from github import Github

from kubeinit_ci_utils import upload_logs
# from kubeinit_ci_utils import remove_label, upload_logs

#
# We only execute the submariner job for a specific PR
#


def main():
    """Run the main method."""
    gh = Github(os.environ['GH_TOKEN'])
    gh_token = os.environ['GH_TOKEN']

    vars_file_path = os.getenv('VARS_FILE', "")
    pipeline_id = os.getenv('CI_PIPELINE_ID', 0)

    repo = gh.get_repo("submariner-io/submariner-operator")
    branches = repo.get_branches()

    output = 0
    # Something linke:
    # url = "https://gitlab.com/kubeinit/kubeinit-ci/pipelines/"
    url = os.getenv('CI_PIPELINE_URL', "")
    print("The job results will be published in runtime at: " + url)

    for branch in branches:
        for pr in repo.get_pulls(state='open', sort='created', base=branch.name):
            labels = [item.name for item in pr.labels]

            sha = pr.head.sha
            committer_email = repo.get_commit(sha=sha).commit.committer.email
            print(committer_email)

            execute = False
            scenario = "default"

            #
            # Charmed Distribution of Kubernetes
            #
            if ("check-okd-rke" in labels):
                distro = "multiple"
                driver = "libvirt"
                master = "1"
                worker = "2"
                execute = True
                scenario = "submariner"
                # remove_label("check-okd-rke", pr)

            if execute:
                print("Let's run the e2e job, distro %s driver %s " % (distro, driver))
                print("-------------")
                print("-------------")
                print("Running the e2e job for: " + str(pr.number) + " " + pr.title)
                print("-------------")
                print("-------------")
                print("-------------")

                # We update the status to show that we are executing the e2e test
                print("Current status")
                print(repo.get_commit(sha=sha).get_statuses())
                # repo.get_commit(sha=sha).create_status(state="pending",
                #                                        target_url=url + str(pipeline_id),
                #                                        description="Running...",
                #                                        context="%s-%s-%s-master-%s-worker-%s" % (distro,
                #                                                                                  driver,
                #                                                                                  master,
                #                                                                                  worker,
                #                                                                                  scenario))
                print("The pipeline ID is: " + str(pipeline_id))
                print("The clouds.yml path is: " + str(vars_file_path))
                # We trigger the e2e job
                start_time = time.time()
                try:
                    print("We call the downstream job configuring its parameters")
                    subprocess.check_call("./ci/run_submariner.sh %s %s %s %s %s %s %s %s" % (str(branch.name),
                                                                                              str(pr.number),
                                                                                              str(vars_file_path),
                                                                                              str(distro),
                                                                                              str(driver),
                                                                                              str(master),
                                                                                              str(worker),
                                                                                              str(scenario)),
                                          shell=True)
                except Exception as e:
                    print('An exception hapened executing Ansible')
                    print(e)
                    output = 1

                try:
                    print("Render ara data")
                    subprocess.check_call("./ci/ara.sh %s" % (str(pipeline_id)), shell=True)
                except Exception as e:
                    print('An exception hapened rendering ara data')
                    print(e)
                    output = 1

                print("starting the uploader job")
                upload_logs(pipeline_id, gh_token)
                print("finishing the uploader job")

                if output == 0:
                    state = "success"
                else:
                    state = "failure"

                desc = ("Ended with %s in %s minutes" % (state, round((time.time() - start_time) / 60, 2)))

                print(desc)
                print(state)
                dest_url = 'https://kubeinit-bot.github.io/kubeinit-ci-results/' + pipeline_id + '/'
                print("The destination URL is: " + dest_url)
                # We update the status with the job result
                # repo.get_commit(sha=sha).create_status(state=state,
                #                                        target_url=dest_url,
                #                                        description=desc,
                #                                        context="%s-%s-%s-master-%s-worker-%s" % (distro,
                #                                                                                  driver,
                #                                                                                  master,
                #                                                                                  worker,
                #                                                                                  scenario))
            else:
                print("No need to do anything")
            if execute:
                exit()


if __name__ == "__main__":
    main()
