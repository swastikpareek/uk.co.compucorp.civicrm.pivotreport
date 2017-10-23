<?php

/**
 * Collection of upgrade steps.
 */
class CRM_PivotReport_Upgrader extends CRM_PivotReport_Upgrader_Base {

  /**
   * Installation logic.
   * 
   * @return boolean
   */
  public function install() {
    $this->upgrade_0001();
    $this->upgrade_0002();
    $this->upgrade_0003();

    return TRUE;
  }

  /**
   * Uninstallation logic.
   * 
   * @return boolean
   */
  public function uninstall()
  {
    $this->deleteScheduledJob();

    CRM_Core_DAO::executeQuery("DELETE FROM `civicrm_navigation` WHERE name = 'pivotreport'");
    CRM_Core_BAO_Navigation::resetNavigation();

    return TRUE;
  }

  /**
   * Install Pivot Report link under Reports menu.
   * 
   * @return boolean
   */
  public function upgrade_0001() {
    CRM_Core_DAO::executeQuery("DELETE FROM `civicrm_navigation` WHERE name = 'pivotreport' and parent_id IS NULL");
    $reportsNavId = CRM_Core_DAO::getFieldValue('CRM_Core_DAO_Navigation', 'Reports', 'id', 'name');
    $navigation = new CRM_Core_DAO_Navigation();
    $params = array (
        'domain_id'  => CRM_Core_Config::domainID(),
        'label'      => ts('Pivot Report'),
        'name'       => 'pivotreport',
        'url'        => 'civicrm/activity-report',
        'parent_id'  => $reportsNavId,
        'weight'     => 0,
        'permission' => 'access CiviCRM pivot table reports',
        'separator'  => 1,
        'is_active'  => 1
    );
    $navigation->copyValues($params);
    $navigation->save();
    CRM_Core_BAO_Navigation::resetNavigation();

    return TRUE;
  }

  /**
   * Creates scheduled job to build pivot report cache, checking if it exists
   * first.
   */
  public function upgrade_0002() {
    if (!$this->getScheduledJobId()) {
      $this->createScheduledJob();
    }

    return TRUE;
  }

  /**
   * Installs Pivot Report config db table (if does not exist).
   *
   * @return TRUE
   */
  public function upgrade_0003() {
    $this->executeSqlFile('sql/civicrm_pivotreport_config_install.sql');

    return TRUE;
  }

  /**
   * Removes all existing scheduled jobs for the extension and install one
   * new scheduled job.
   *
   * @return bool
   */
  public function upgrade_0004() {
    $jobs = civicrm_api3('Job', 'get', array(
      'sequential' => 1,
      'api_entity' => 'PivotReport',
      'api_action' => 'rebuildcache',
    ));

    foreach ($jobs['values'] as $job) {
      $this->deleteScheduledJob($job['id']);
    }

    $this->createScheduledJob();

    return TRUE;
  }

  /**
   * Logic which is executing when enabling extension.
   * 
   * @return boolean
   */
  public function onEnable() {
    $this->setScheduledJobIsActive(TRUE);

    CRM_Core_DAO::executeQuery("UPDATE civicrm_navigation SET is_active = 1 WHERE name = 'pivotreport'");
    CRM_Core_BAO_Navigation::resetNavigation();

    return TRUE;
  }

  /**
   * Logic which is executing when disabling extension.
   * 
   * @return boolean
   */
  public function onDisable() {
    $this->setScheduledJobIsActive(FALSE);

    CRM_Core_DAO::executeQuery("UPDATE civicrm_navigation SET is_active = 0 WHERE name = 'pivotreport'");
    CRM_Core_BAO_Navigation::resetNavigation();

    return TRUE;
  }

  /**
   * Returns an ID of schedule job or NULL if the job does not exist.
   *
   * @return int|NULL
   */
  private function getScheduledJobId() {
    $result = civicrm_api3('Job', 'get', array(
      'sequential' => 1,
      'api_entity' => 'PivotReport',
      'api_action' => 'rebuildcache',
      'limit' => 1,
    ));

    if (empty($result['id'])) {
      return NULL;
    }

    return $result['id'];
  }

  /**
   * Sets schedule job active state.
   *
   * @param bool $isActive
   */
  private function setScheduledJobIsActive($isActive) {
    $id = $this->getScheduledJobId();
    if (!$id) {
      return NULL;
    }

    civicrm_api3('Job', 'update', array(
      'id' => $id,
      'is_active' => (int) $isActive,
    ));
  }

  /**
   * Creates a scheduled job entry.
   */
  private function createScheduledJob() {
    civicrm_api3('Job', 'create', array(
      'run_frequency' => 'Daily',
      'name' => 'Pivot Report Cache Build',
      'description' => 'Job to rebuild the cache that is used to build pivot tble reports.',
      'api_entity' => 'PivotReport',
      'api_action' => 'rebuildcache',
    ));
  }

  /**
   * Deletes schedule job.
   *
   * @param int $id
   */
  private function deleteScheduledJob($id = NULL) {
    if (!$id) {
      $id = $this->getScheduledJobId();
    }
    if (!$id) {
      return NULL;
    }

    civicrm_api3('Job', 'delete', array(
      'id' => $id,
    ));
  }
}
